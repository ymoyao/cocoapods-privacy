### common
require 'cocoapods-privacy/common/config'
require 'cocoapods-privacy/common/BBSpec'
require 'cocoapods-privacy/common/BBSpecManager'


### privacy
require 'cocoapods-privacy/command/privacy'
require 'cocoapods-privacy/command/privacy/config'
require 'cocoapods-privacy/command/privacy/install'
require 'cocoapods-privacy/command/privacy/spec'
require 'cocoapods-privacy/command/install'
require 'cocoapods-privacy/privacy/privacy_specification_hook'
require 'cocoapods-privacy/privacy/privacy_installer_hook'
require 'cocoapods-privacy/privacy/PrivacyUtils'
require 'cocoapods-privacy/privacy/PrivacyModule'
require 'cocoapods-privacy/privacy/PrivacyHunter'
require 'cocoapods-privacy/privacy/PrivacyLog'

## mix
require 'cocoapods-privacy/command/confuse/spec'
require 'cocoapods-privacy/confuse/confuse_installer_hook'
require 'cocoapods-privacy/confuse/confuse_specification_hook'
require 'cocoapods-privacy/confuse/ConfuseUtils'
require 'cocoapods-privacy/confuse/ConfuseModule'
require 'cocoapods-privacy/confuse/ConfuseHunter'
require 'cocoapods-privacy/confuse/ObjCMethodAPIConverter'
require 'cocoapods-privacy/confuse/SwiftCallAssembly'


