# StaticPodGenerator

生成指定pod对应的静态库的pod  
源码打包成.a或者.framework【根据参数决定  
xib会编译成nib  
其他资源不处理直接保留  
不过最终产物里podspec.json中的version以及source字段还需要进行编辑才可以

## Installation

```bash
./install.sh
```

## Usage

### 在Ruby代码中使用
```ruby
StaticPodGenerator::run(
    pod_line: '"pod \'MangoFix\', \'1.4.0\'"',
    repo_source: 'source \'http://git.17usoft.com/elongspecs/elongspecs.git\'',
    platform_version: '9.0',
    is_library: false,
    configuration: 'Release',
    output_path: '.'
)
```

### 在命令行中使用
```bash
# 其他参数就不写了自己看help吧
staticPodGenerator -p "pod 'MangoFix', '1.4.0'"
```
