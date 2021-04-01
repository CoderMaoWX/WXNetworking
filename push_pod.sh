#!/bin/sh


#发布WXNetwork网络库
#pod trunk push WXNetworking.podspec --allow-warnings --verbose --use-libraries


#拉取最新
git pull

VersionString=`grep -E 'spec.version.*=' WXNetworking.podspec`
VersionNumber=`tr -cd 0-9 <<<"$VersionString"`

NewVersionNumber=$(($VersionNumber + 0.1))
LineNumber=`grep -nE 'spec.version.*=' WXNetworking.podspec | cut -d : -f1`
sed -i "" "${LineNumber}s/${VersionNumber}/${NewVersionNumber}/g" WXNetworking.podspec

echo "\033[41;36m 当前版本号为: ${VersionNumber}, 新制作的版本号为: ${NewVersionNumber} \033[0m "

#提交所有修改
git add .
git commit -am "打 tag: ${NewVersionNumber}"

#提交所有修改推到Gitlab
git push


#删除本地相同的版本号(那最新的)
git tag -d ${NewVersionNumber}

#打tag推上远程pod
git tag ${NewVersionNumber}
git push --tags

# 制作并推到远程库
pod trunk push WXNetworking.podspec --allow-warnings --verbose --use-libraries


if [ $? == 0 ] ; then

    echo "\033[41;36m 第三方库 WXNetworking Pod库制作成功, 请在项目中使用: pod 'WXNetworking' 导入 \033[0m "
    
    NewVersionURL="https://cocoapods.org/pods/WXNetworking"
    echo "最新版本号: $NewVersionURL"
    open $NewVersionURL
    
else
    echo "\033[41;36m 第三方库 WXNetworking Pod库制作失败, 请查看终端打印日志排查原因 \033[0m "
fi
