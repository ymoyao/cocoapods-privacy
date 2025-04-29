module Confuse
    class SwiftCallAssembly

        #method_confuse 用来替换掉函数名 儒 BB_Confuse_asdasfas
        #swift 完整函数 如  @objc public func calculateAreaWithWidth(width: (Bool, String) -> Void, height: CGFloat) -> CGFloat
        #params 参数名数组 width, height
        def self.assembly(method_confuse,swift_method_declaration,params)
            is_return = true
            is_static = swift_method_declaration.start_with?("static")
            caller = is_static ? "Self" : "self"
            returnFlag = is_return ? "return " : ""
            
            params = params.map.with_index do |param, index|
                if index == 0
                    param
                else
                    "#{param}: #{param}"
                end
            end
            funcBody = "#{swift_method_declaration} {\n   #{returnFlag}#{caller}.#{method_confuse}(#{params.join(', ')})\n}"
            return funcBody
        end
    end
end