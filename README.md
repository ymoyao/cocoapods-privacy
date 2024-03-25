# cocoapods-privacy

Apple 2024 will review the App's privacy list in the spring, and any apps that don't submit a privacy list may be called back. For now, the privacy list is broken down by component, to facilitate the maintenance of component privacy, cocoapods-privacy is developed for management.
[Click to view details on Apple](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)

## Installation
```
$ gem install cocoapods-privacy
```

## Usage
### init
First of all, you must set a json config to cocoapods-privacy, this is a defalut config.json
```
$ pod privacy config https://raw.githubusercontent.com/ymoyao/cocoapods-privacy/main/resources/config.json
```

There has 3 keys in defalut config, defalut rule is ：To exclude retrieval a component that git source contains certain ‘github.com’ keywords
```
"source.white.list": [],
"source.black.list": ["github.com"], 
"api.template.url": "https://raw.githubusercontent.com/ymoyao/cocoapods-privacy/main/resources/NSPrivacyAccessedAPITypes.plist"
```
* source.white.list : a white list of source, it effective in command 'pod privacy install' or 'pod install --privacy', will search white list for NSPrivacyAccessedAPITypes.
  * when the whitelist is an empty array, it means all components are whitelist(default config).
  * when the whitelist is not empty, it means only the components in the whitelist array are retrieved.
* source.black.list : a black list of source, defalut is ‘github.com’, based on the whitelist, the components need to be excluded。 it effective in command 'pod privacy install' or 'pod install --privacy'. 
* api.template.url : its required, a template for search NSPrivacyAccessedAPITypes, you can use the provided by default。

If your needs are not met, you can custom! For example, there has some components，and it‘s your local config
```
"source.white.list": ["https://github.com/ReactiveCocoa/ReactiveObjC.git","git.yourserver.com","git.otherserver.com"],
"source.black.list": ["github.com","https://github.com/AFNetworking/AFNetworking.git"], 
"api.template.url": "https://raw.githubusercontent.com/ymoyao/cocoapods-privacy/main/resources/NSPrivacyAccessedAPITypes.plist"
```

```
https://github.com/AFNetworking/AFNetworking.git ❌ (it's in 'github.com' black list)
https://github.com/ReactiveCocoa/ReactiveObjC.git ❌ (it's in 'github.com' black list, although also on the white list,but the blacklist priority is high when conflict)
https://git.yourserver.com/xxx/xxxx.git ✅
https://git.yourserver.com/mmm/mmm.git ✅
https://git.otherserver.com/ssss/ssss.git ✅
https://git.yourserver.com/AFNetworking/AFNetworking.git ✅
```

After custom,you just update config by local like this
```
$ pod privacy config /yourfilepath/config.json
```
In a word, if you define both white and black lists ,final search range: white list minus black list, and empty white list means all!


### To Component
```
$ pod privacy spec [podspec_file_path]
```
This command will auto create privacy file, and search the path of podspec' source_files' define relate to NSPrivacyAccessedAPITypes, finaly, write to PrivacyInfo.xcprivacy file.
if your component has much subspec,  all subspec that define ‘source_files’ will create PrivacyInfo.xcprivacy, and auto modify .podspec link .xcprivacy to 'resource_bundle' key.
For example
* origin podspec

```
Pod::Spec.new do |s|
  s.name             = 'Demo'
  ...
  s.source_files = 'xxxx'
  s.subspec 'idfa' do |sp|
      sp.source_files = 'xxxxx'
  end
  s.subspec 'noidfa' do |sp|
  end
end

```

* podspec after commad  👇👇👇👇👇👇
```
Pod::Spec.new do |s|
  s.name             = 'Demo'
  ...
  s.source_files = 'xxxx'
  s.resource_bundle = {"Demo.privacy"=>"Pod/Privacy/Demo/PrivacyInfo.xcprivacy"}
  s.subspec 'idfa' do |sp|
      sp.source_files = 'xxxxx'
      sp.resource_bundle = {"Demo.idfa.privacy"=>"Pod/Privacy/Demo.idfa/PrivacyInfo.xcprivacy"}
  end
  s.subspec 'noidfa' do |sp|
  end
end
```
<img width="961" alt="截屏2024-02-02 11 23 21" src="https://github.com/ymoyao/cocoapods-privacy/assets/13619221/a6678c8e-c4aa-4f7d-8881-657c6d703657">


    
### To Project
```
$ pod install --privacy
or
$ pod privacy install
```
<img width="298" alt="截屏2024-02-02 10 59 59" src="https://github.com/ymoyao/cocoapods-privacy/assets/13619221/c6f10e36-0f62-497a-93d4-f8b336dc8df4">

After command, a PrivacyInfo.xcprivacy will create to you project Resources if empty. and it will search component that configuration files allow and do not have their own privacy manifest file.

## Notice
The plugin is focus on NSPrivacyAccessedAPITypes and automatically search and create workflow.
you should manager NSPrivacyCollectedDataTypes by yourself！
    

