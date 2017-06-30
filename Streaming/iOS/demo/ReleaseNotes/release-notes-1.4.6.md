# PLCameraStreamingKit Release Notes for 1.4.5

## 内容

- [简介](#简介)
- [问题反馈](#问题反馈)
- [记录](#记录)
	
## 简介

PLCameraStreamingKit 为 iOS 开发者提供直播推流 SDK。

## 问题反馈

当你遇到任何问题时，可以通过在 GitHub 的 repo 提交 ```issues``` 来反馈问题，请尽可能的描述清楚遇到的问题，如果有错误信息也一同附带，并且在 ```Labels``` 中指明类型为 bug 或者其他。

[通过这里查看已有的 issues 和提交 Bug](https://github.com/pili-engineering/PLCameraStreamingKit/issues)

## 记录

### bug

- 修复弱网环境下切换 VideoQuality 可能触发的 crash 问题

### 音频数据源

- 添加 `PLAudioComponentFailedToCreateNotification` 通知，在音频资源被占用时，创建音频结构失败会发送这个通知