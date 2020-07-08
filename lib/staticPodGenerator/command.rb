#!/usr/bin/env ruby



require 'set'
require 'cocoapods'
require 'fileutils'
require 'json'
require_relative 'dependencyAnalyzer'


module StaticPodGenerator
    def self.run(
            pod_line: nil,
            repo_source: nil,
            platform_version: nil,
            configuration: nil,
            is_library: false,
            output_path: nil
        )
        if pod_line.nil?
            exit 1
        end

        FileUtils.rm('Podfile.lock', :force => true)
        FileUtils.rm_rf('Pods')
        FileUtils.mkdir_p('tmp')

        if is_library
            ENV['LIBRARY'] = '1'
        end

        podfile_content = File.read(File.expand_path('../../../resources/PodfileTemplate', __FILE__))
        podfile_content = podfile_content.gsub('#repo_source#', repo_source)
        podfile_content = podfile_content.gsub('#platform_version#', platform_version)
        podfile_content = podfile_content.gsub('#configuration#', configuration)
        podfile_content = podfile_content.gsub('#pod_line#', pod_line)
        File.open('Podfile', 'w') {
            |file|
            file.puts podfile_content 
        }
        Pod::Command.run(['update', '--verbose', '--no-repo-update'])

        # 读取原始的spec
        pod = Pod::Podfile.from_file('Podfile').dependencies[0]
        pod_name = pod.name.split('/').first
        origin_spec = JSON.parse(File.read(File.join('tmp', pod_name + '.podspec.json')))

        if is_library
            # .a需要手动合并
            cmd_str = 'lipo -create %s %s -output %s' % [File.join('build', 'Release-iphoneos', pod_name, 'lib' + pod_name + '.a'), File.join('build', 'Release-iphonesimulator', pod_name, 'lib' + pod_name + '.a'), File.join('build', 'lib' + pod_name + '.a')]
            print %x[ #{cmd_str} ]
        end

        # 裁剪掉i386
        if is_library
            cmd_str = 'lipo -remove i386 %s -output %s' % [File.join('build', 'lib' + pod_name + '.a'), File.join('build', 'lib' + pod_name + '.a')]
            print %x[ #{cmd_str} ]
        else
            cmd_str = 'lipo -remove i386 %s -output %s' % [File.join('build', origin_spec['name'] + '.framework', origin_spec['name']), File.join('build', origin_spec['name'] + '.framework', origin_spec['name'])]
            print %x[ #{cmd_str} ]
        end

        # 生成静态库的spec
        # 首先是必须的字段
        new_spec = {}
        new_spec['name'] = origin_spec['name'] + 'Static'
        new_spec['version'] = '1.0.0'
        new_spec['authors'] = origin_spec['authors']
        new_spec['license'] = origin_spec['license']
        new_spec['homepage'] = ""
        new_spec['source'] = {}
        new_spec['summary'] = 'StaticFramework of ' + origin_spec['name']
        new_spec['platforms'] = origin_spec['platforms']
        new_spec['vendored_frameworks'] = 'vendored_frameworks/*.framework'
        new_spec['vendored_libraries'] = 'vendored_libraries/*.a'
        if is_library
            new_spec['source_files'] = 'headers/*.h'
        end
        # spec跟subspec共有的属性
        pa_list = ['dependencies', 'frameworks', 'weak_frameworks', 'libraries', 'resources']
        pa_list.each { |pa|
            if pa == 'dependencies'
                new_spec[pa] = Hash(origin_spec[pa])
            else
                new_spec[pa] = Array(origin_spec[pa])
            end
        }

        # 初始化并查集
        # 用并查集处理subspec互相依赖的情况
        dependency_analyzer = DependencyAnalyzer.new
        Array(origin_spec['subspecs']).each { |subspec|
            Hash(subspec['dependencies']).each { |dependency, _|
                if dependency.include?(origin_spec['name'])
                    dependency_analyzer.dependency(subspec['name'], dependency.split('/').last)
                end
            }
        }

        # 处理subspec里的字段
        # 首先找出所有依赖的子模块
        dependent_specs = []
        if pod.name.include?('/')
            # 指定了子模块的情况
            # 寻找对应的子模块
            # 这里只考虑子模块A依赖子模块B这种单层依赖
            # 暂不考虑A依赖B，B依赖C这种多层依赖的情况
            specified_spec = pod.name.split('/').last
            origin_spec['subspecs'].each { |subspec|
                if dependency_analyzer.dependency?(specified_spec, subspec['name'])
                    dependent_specs.append(subspec)
                end
            }
        else
            # 没指定子模块的情况
            # 先看看这个pod有没有子模块没有就算了
            if origin_spec['subspecs']
                if origin_spec['default_subspecs']
                    # 如果有默认的用默认的子模块
                    origin_spec['subspecs'].each { |subspec|
                        Array(origin_spec['default_subspecs']).each { |default_subspec|
                            if dependency_analyzer.dependency?(default_subspec, subspec['name'])
                                dependent_specs.append(subspec)
                                break
                            end
                        }
                    }
                else
                    # 没有默认就用全部子模块
                    origin_spec['subspecs'].each { |subspec|
                        dependent_specs.append(subspec)
                    }
                end
            end
        end

        # 把子模块的属性合并到主模块
        dependent_specs.each { |subspec|
            pa_list.each { |pa|
                if subspec[pa]
                    if pa == 'dependencies'
                        Hash(subspec['dependencies']).each { |dependency, options|
                            if !dependency.include?(origin_spec['name'] + '/')
                                new_spec[pa][dependency] = options
                            end
                        }
                    else
                        new_spec[pa] = Array(new_spec[pa].to_set + Array(subspec[pa]).to_set)
                    end
                end
            }
        }

        # 处理resources，去掉路径跟文件名只保留后缀
        new_resources = []
        new_spec['resources'].each { |resource|
            extension_list = resource.split('.').last.delete('{}').split(',')
            extension_list.each { |extension|
                new_resource = File.join('resources', '*.' + extension)
                if !new_resources.include?(new_resource)
                    new_resources.append(new_resource)
                end
            }
        }
        new_spec['resources'] = new_resources

        # 处理除了源码之外的文件
        # 根据.framework, .a, 以及resources里的后缀来匹配
        # 暂不支持resource_bundles
        xcproj = Xcodeproj::Project.open('Pods/Pods.xcodeproj')
        pod_group = nil
        if xcproj['Development Pods']
            if xcproj['Development Pods'][origin_spec['name']]
                pod_group = xcproj['Development Pods'][origin_spec['name']]
            end
        else
            if xcproj['Pods'][origin_spec['name']]
                pod_group = xcproj['Pods'][origin_spec['name']]
            end
        end

        need_copy_file_paths = []
        if is_library
            need_copy_file_paths.append(File.join('build', 'lib' + origin_spec['name'] + '.a'))
        else
            need_copy_file_paths.append(File.join('build', origin_spec['name'] + '.framework'))
        end
        pod_group.recursive_children.each { |child|
            if child.kind_of?(Xcodeproj::Project::Object::PBXFileReference)
                if child.parent.name.end_with?(".bundle")
                    next
                end

                child_extension = child.display_name.split('.').last
                if child_extension == 'h'
                    if is_library
                        need_copy_file_paths.append(child.real_path.to_s)
                    end
                elsif child_extension == 'a' || child_extension == 'framework' || new_spec['resources'].include?(File.join('resources', '*.' + child_extension))
                    need_copy_file_paths.append(child.real_path.to_s)
                end
            end
        }

        # 生成静态库pod文件夹并复制所需的文件
        dest_path = nil
        if output_path
            dest_path = output_path
        else
            FileUtils.rm_rf(new_spec['name'])
            FileUtils.mkdir_p(new_spec['name'])
            dest_path = new_spec['name']
        end
        FileUtils.mkdir_p(File.join(dest_path, 'vendored_frameworks'))
        FileUtils.mkdir_p(File.join(dest_path, 'vendored_libraries'))
        FileUtils.mkdir_p(File.join(dest_path, 'resources'))
        if is_library
            FileUtils.mkdir_p(File.join(dest_path, 'headers'))
        end
        need_copy_file_paths.each { |path|
            extension = path.split('.').last
            if extension == 'framework'
                FileUtils.cp_r(path, File.join(dest_path, 'vendored_frameworks'))
            elsif extension == 'a'
                FileUtils.cp_r(path, File.join(dest_path, 'vendored_libraries'))
            elsif extension == 'h'
                FileUtils.cp_r(path, File.join(dest_path, 'headers'))
            else
                FileUtils.cp_r(path, File.join(dest_path, 'resources'))
            end
        }
        # 生成podspec
        File.open(File.join(dest_path, new_spec['name'] + '.podspec.json'), 'w') {
            |file|
            file.puts JSON.pretty_generate(new_spec)
        }
    end
end