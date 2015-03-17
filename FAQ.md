## Q: How to access file detail when got link for download? ##

## A: Delete part of download link after '?' ##
Example download:
```
   http://localhost:3000/dmsf_files/10?download= 
```
Detail:
```
   http://localhost:3000/dmsf_files/10 
```

## Q: Why can't I download or email multiple entries? ##
Got error in both cases:
```
MissingSourceFile (no such file to load -- zip/zip):
  vendor/plugins/redmine_dmsf/app/helpers/dmsf_zip.rb:19
  ...
```

## A: Check you have gem rubyzip installed ##
As stated in instalation guide


---


## Q: What is proper Zip filenames encoding for Czech alphabet on MS Windows? ##

## A: cp852 ##


---


## Q: What is proper Zip filenames encoding for Chinese characters? ##

## A: gbk ##
But it will vary on variant and target system


---


## Q: What is proper Zip filenames encoding for Japanese characters? ##

## A: shift-jis ##