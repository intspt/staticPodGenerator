module StaticPodGenerator
    class DependencyAnalyzer
        def initialize
            @father = {}
        end

        # a依赖b
        def dependency(a, b)
            if !@father[b]
                @father[b] = []
            end
            @father[b] += [a]
        end

        # a是否依赖b
        def dependency?(a, b)
            # a如果依赖b那么b的father或者father的father中一定有一个是a
            # 递归寻找所有的father即可
            if a == b
                return true
            end
            Array(@father[b]).each { |c|
                if c == a
                    return true
                elsif dependency?(a, c)
                    return true
                end
            }
            return false
        end
    end
end