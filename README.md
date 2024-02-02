# cocoapods-privacy

Apple 2024 will review the App's privacy list in the spring, and any apps that don't submit a privacy list may be called back. For now, the privacy list is broken down by component, to facilitate the maintenance of component privacy, cocoapods-privacy is developed for management.
[Click to view details on Apple](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)

## Installation

    $ gem install cocoapods-privacy

## Usage
#### init
First of all, you must set a json config to cocoapods-privacy, this is a defalut config.json
```
$ pod privacy config https://raw.githubusercontent.com/ymoyao/cocoapods-privacy/main/resources/config.json
```

There has 3 keys in defalut config, you should custom it!
* source.white.list : a white list of source, defalut is empty, so, you should add you self component sources, and it work in command 'pod privacy install' or 'pod install --privacy', will search white list for NSPrivacyAccessedAPITypes.
* source.black.list : a black list of source, defalut is empty, it work in command 'pod privacy install' or 'pod install --privacy'.
* api.template.url : its required, a template for search NSPrivacyAccessedAPITypes
```
"source.white.list": ["replace me with yourserver"], 
"source.black.list": ["replace me such as github.com"],
"api.template.url": "https://github.com/ymoyao/cocoapods-privacy/blob/main/resources/NSPrivacyAccessedAPITypes.plist"
```

#### To Component
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


    
#### To Project
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
    

