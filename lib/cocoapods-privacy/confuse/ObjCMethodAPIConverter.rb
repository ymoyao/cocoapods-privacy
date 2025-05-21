
module Confuse
  class ObjCMethodAPIConverter
      # Regular expression to match Objective-C method declarations
      # def initialize
  
        # @blockRegex = /#{ConfuseUtils.oc_block_regular}/
        # @regex = /#{ConfuseUtils.noneBlock}/
        @param_regex = /(\w+):\s*\(([^:]+)\)(\w+)/x
      # end
    
      # Convert an Objective-C method declaration to a Swift method declaration
      def self.convert(objc_method_declaration)
        # puts "objc_method_declaration = #{objc_method_declaration}"
        # Skip methods containing blocks
    #    return nil if objc_method_declaration.include?("^")
    
        is_static = objc_method_declaration.start_with?("+")
        preFuncDes = is_static ? "static " : ""
    
        regular = ConfuseUtils.oc_func_regular(objc_method_declaration,true)
        # Match the method declaration using the regex
        matches = objc_method_declaration.match(regular)
        return nil,nil unless matches

        # Extract components from the matched regex groups
        return_type = matches[2] || "Void"
        method_name = matches[3]
        param_section = (matches[3] + (matches[4] || "")) || ""
        # puts "matches = #{matches}"
        # puts "objc_method_declaration = #{objc_method_declaration}"
        # puts  "return_type = #{return_type}"
        # puts  "param_section = #{param_section}"
        # puts "method_name = #{method_name}"

        is_nullable = return_type.include?("nullable")

        # Convert return type to Swift equivalent
        return_type = convert_oc_type_to_swift(return_type)
        return_type.gsub!(Regexp.union('nullable', 'nonnull', 'null_unspecified', 'null_resettable'), '')
    
        # Extract parameters from the method declaration
        params = extract_parameters(param_section)
        method_name = extract_methodName(param_section,method_name)
    
        # Construct the Swift method declaration
        swift_method_declaration = "#{preFuncDes}public func #{method_name}(#{params.join(', ')})"
        swift_method_declaration += " -> #{return_type}" unless return_type == "Void"
        
        return is_nullable, return_type, swift_method_declaration,  extract_parameter_names(param_section)
      end
    
      private
    
      # Convert the Objective-C return type to a Swift type
      def self.convert_oc_type_to_swift(return_type)
        return ConfuseUtils.convert_oc_type_to_swift(return_type)
      end
    
      # Extract parameters from the parameter section
      def self.extract_parameters(param_section)
        params = []
        param_section.scan(@param_regex).each_with_index do |param_info, index|
        #  puts "param_info = #{param_info}"
          param_define, param_type, param_name = param_info
          param_type = convert_oc_type_to_swift(param_type.strip)
          if index == 0
            params << "#{param_name}: #{param_type}"
          else
            params << "#{param_define}: #{param_type}"
          end
        end
        params
      end
      
      def self.extract_parameter_names(param_section)
        names = []
        param_section.scan(@param_regex).each_with_index do |param_info, index|
          param_define, param_type, param_name = param_info
          if index == 0
            names << param_name
          else
            names << param_define
          end
        end
        names
      end
      
      
      def self.extract_methodName(param_section, defalut_method_name)
        method_name = defalut_method_name
        param_section.scan(@param_regex).each_with_index do |param_info, index|
          param_define, param_type, param_name = param_info
          if index == 0
              method_name = param_define
              break
          end
        end
        method_name.strip
      end
    
      
     
  end
end
  