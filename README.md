# cocoapods-privacy

Apple 2024 will review the App's privacy list in the spring, and any apps that don't submit a privacy list may be called back. For now, the privacy list is broken down by component, to facilitate the maintenance of component privacy, cocoapods-privacy is developed for management.

## Installation

    $ gem install cocoapods-privacy

## Usage
#### init
First of all, you must set a json config to cocoapods-privacy
    $ pod privacy config 
#### To Component
    $ pod privacy spec [podspec_file_path]
#### To Project
    
    $ pod install --privacy
    or
    $ pod privacy install


    

