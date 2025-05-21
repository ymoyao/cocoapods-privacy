module Confuse
    class SwiftCallAssembly

        #method_confuse 用来替换掉函数名 儒 BB_Confuse_asdasfas
        #swift 完整函数 如  @objc public func calculateAreaWithWidth(width: (Bool, String) -> Void, height: CGFloat) -> CGFloat
        #params 参数名数组 width, height
        def self.assembly(method_confuse,swift_method_declaration,params, is_nullable, return_type)
            is_return = (return_type != "Void")
            is_static = swift_method_declaration.start_with?("static")
            caller = is_static ? "Self" : "self"
            returnFlag = is_return ? "return " : ""
            optional = is_nullable ? "?" : ""
            
            params = params.map.with_index do |param, index|
                if index == 0
                    param
                else
                    "#{param}: #{param}"
                end
            end
            funcBody = "#{swift_method_declaration}#{optional} {\n   #{returnFlag}#{caller}.#{method_confuse}(#{params.join(', ')})\n}"
            return funcBody
        end

        #把oc属性组装成swift 计算属性
        def self.assemblyProperty(property_origin, property_confuse, return_type, is_nullable)

            final_return_type = (is_nullable ? "#{return_type}?" : return_type)

            #如果是Any
            funcBody = "public var #{property_origin} : #{final_return_type} {\n    get {\n        #{property_confuse}\n    }\n    set {\n        self.#{property_confuse} = newValue\n    }\n}\n"
            return funcBody
        end
    end
end