//
//  LiveRoomViewController.swift
//  OpenLive
//
//  Created by GongYuhua on 6/25/16.
//  Copyright © 2016 Agora. All rights reserved.
//

import UIKit

protocol LiveRoomVCDelegate: NSObjectProtocol {
    func liveVCNeedClose(_ liveVC: LiveRoomViewController)
}

class LiveRoomViewController: UIViewController {
    
    @IBOutlet weak var roomNameLabel: UILabel!
    @IBOutlet weak var remoteContainerView: UIView!
    @IBOutlet weak var broadcastButton: UIButton!
    @IBOutlet var sessionButtons: [UIButton]!
    @IBOutlet weak var audioMuteButton: UIButton!
    @IBOutlet weak var enhancerButton: UIButton!
    
    
    // 本设备 uid
    var myUid: UInt = 0
    // uid 数组
    var uidArray = NSMutableArray()
    // 画中画布局
    var compositingLayout = AgoraRtcVideoCompositingLayout()
   
    
    var roomName: String!
    var clientRole = AgoraRtcClientRole.clientRole_Audience {
        didSet {
            if isBroadcaster {
                shouldEnhancer = true
            }
            updateButtonsVisiablity()
        }
    }
    var isOwner: Bool!
    var videoProfile: AgoraRtcVideoProfile!
    weak var delegate: LiveRoomVCDelegate?
    
    //MARK: - engine & session view
    var rtcEngine: AgoraRtcEngineKit!
    fileprivate lazy var agoraEnhancer: AgoraYuvEnhancerObjc? = {
        let enhancer = AgoraYuvEnhancerObjc()
        enhancer.lighteningFactor = 0.7
        enhancer.smoothness = 0.7
        return enhancer
    }()
    fileprivate var isBroadcaster: Bool {
        return clientRole == .clientRole_Broadcaster
    }
    fileprivate var isMuted = false {
        didSet {
            rtcEngine?.muteLocalAudioStream(isMuted)
            audioMuteButton?.setImage(UIImage(named: isMuted ? "btn_mute_cancel" : "btn_mute"), for: .normal)
        }
    }
    fileprivate var shouldEnhancer = true {
        didSet {
            if shouldEnhancer {
                agoraEnhancer?.turnOn()
            } else {
                agoraEnhancer?.turnOff()
            }
            enhancerButton?.setImage(UIImage(named: shouldEnhancer ? "btn_beautiful_cancel" : "btn_beautiful"), for: .normal)
        }
    }
    
    fileprivate var videoSessions = [VideoSession]() {
        didSet {
            guard remoteContainerView != nil else {
                return
            }
            updateInterface(withAnimation: true)
        }
    }
    fileprivate var fullSession: VideoSession? {
        didSet {
            if fullSession != oldValue && remoteContainerView != nil {
                updateInterface(withAnimation: true)
            }
        }
    }
    
    fileprivate let viewLayouter = VideoViewLayouter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        roomNameLabel.text = roomName
        updateButtonsVisiablity()
        
        loadAgoraKit()
    }
    
    //MARK: - user action
    @IBAction func doSwitchCameraPressed(_ sender: UIButton) {
        rtcEngine?.switchCamera()
    }
    
    @IBAction func doMutePressed(_ sender: UIButton) {
        isMuted = !isMuted
    }
    
    @IBAction func doEnhancerPressed(_ sender: UIButton) {
        shouldEnhancer = !shouldEnhancer
    }
    
    @IBAction func doBroadcastPressed(_ sender: UIButton) {
        if isBroadcaster {
            clientRole = .clientRole_Audience
            if fullSession?.uid == 0 {
                fullSession = nil
            }
            
            uidArray.removeObject(at: 0)
            print("uid ============本设备用户离线回调============ ")

            
        } else {
            clientRole = .clientRole_Broadcaster
            
            uidArray.insert(myUid, at: 0)
            print("uid ============本设备用户上线回调============ ")
        }
        
        rtcEngine.setClientRole(clientRole, withKey: nil)
        layoutAgoraRtcVideoCompositing()

        updateInterface(withAnimation :true)
        
    }
    
    @IBAction func doDoubleTapped(_ sender: UITapGestureRecognizer) {
        if fullSession == nil {
            if let tappedSession = viewLayouter.responseSession(of: sender, inSessions: videoSessions, inContainerView: remoteContainerView) {
                fullSession = tappedSession
            }
        } else {
            fullSession = nil
        }
    }
    
    @IBAction func doLeavePressed(_ sender: UIButton) {
        leaveChannel()
    }
}

private extension LiveRoomViewController {
    func updateButtonsVisiablity() {
        guard let sessionButtons = sessionButtons else {
            return
        }
        
        broadcastButton?.setImage(UIImage(named: isBroadcaster ? "btn_join_cancel" : "btn_join"), for: UIControlState())
        
        for button in sessionButtons {
            button.isHidden = !isBroadcaster
        }
    }
    
    func leaveChannel() {
        setIdleTimerActive(true)
        
        rtcEngine.setupLocalVideo(nil)
        rtcEngine.leaveChannel(nil)
        if isBroadcaster {
            rtcEngine.stopPreview()
        }
        
        for session in videoSessions {
            session.hostingView.removeFromSuperview()
        }
        videoSessions.removeAll()
        
        agoraEnhancer?.turnOff()
        
        delegate?.liveVCNeedClose(self)
    }
    
    func setIdleTimerActive(_ active: Bool) {
        UIApplication.shared.isIdleTimerDisabled = !active
    }
    
    func alert(string: String) {
        guard !string.isEmpty else {
            return
        }
        
        let alert = UIAlertController(title: nil, message: string, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}

private extension LiveRoomViewController {
    func updateInterface(withAnimation animation: Bool) {
        if animation {
            UIView.animate(withDuration: 0.3, animations: { [weak self] _ in
                self?.updateInterface()
                self?.view.layoutIfNeeded()
            })
        } else {
            updateInterface()
        }
    }
    
    func updateInterface() {
        var displaySessions = videoSessions
        if !isBroadcaster && !displaySessions.isEmpty {
            displaySessions.removeFirst()
        }
        viewLayouter.layout(sessions: displaySessions, fullSession: fullSession, inContainer: remoteContainerView)
        setStreamType(forSessions: displaySessions, fullSession: fullSession)
    }
    
    func setStreamType(forSessions sessions: [VideoSession], fullSession: VideoSession?) {
        if let fullSession = fullSession {
            for session in sessions {
                rtcEngine.setRemoteVideoStream(UInt(session.uid), type: (session == fullSession ? .videoStream_High : .videoStream_Low))
            }
        } else {
            for session in sessions {
                rtcEngine.setRemoteVideoStream(UInt(session.uid), type: .videoStream_High)
            }
        }
    }
    
    func addLocalSession() {
        let localSession = VideoSession.localSession()
        videoSessions.append(localSession)
        rtcEngine.setupLocalVideo(localSession.canvas)
    }
    
    func fetchSession(ofUid uid: Int64) -> VideoSession? {
        for session in videoSessions {
            if session.uid == uid {
                return session
            }
        }
        
        return nil
    }
    
    func videoSession(ofUid uid: Int64) -> VideoSession {
        if let fetchedSession = fetchSession(ofUid: uid) {
            return fetchedSession
        } else {
            let newSession = VideoSession(uid: uid)
            videoSessions.append(newSession)
            return newSession
        }
    }
}

//MARK: - Agora Media SDK
private extension LiveRoomViewController {
    func loadAgoraKit() {
        rtcEngine = AgoraRtcEngineKit.sharedEngine(withAppId: KeyCenter.AppId, delegate: self)
        rtcEngine.setChannelProfile(.channelProfile_LiveBroadcasting)
        rtcEngine.enableDualStreamMode(true)
        rtcEngine.enableVideo()
        rtcEngine.setVideoProfile(videoProfile, swapWidthAndHeight: true)
        rtcEngine.setClientRole(clientRole, withKey: nil)
        
        // 打印SDK的log
        let logNum = rtcEngine.setLogFile("Library/Caches/agorasdk.log")
        print("打印SDK的log设置是否成功 ----------- \(logNum)")
       

        if isBroadcaster {
            rtcEngine.startPreview()
        }
        
        addLocalSession()
        func getJSONStringFromDictionary(dictionary:NSDictionary) -> String {
            if (!JSONSerialization.isValidJSONObject(dictionary)) {
                print("无法解析出JSONString")
                return ""
            }
            let data : NSData! = try? JSONSerialization.data(withJSONObject: dictionary, options: []) as NSData!
            let JSONString = NSString(data:data as Data,encoding: String.Encoding.utf8.rawValue)
            return JSONString! as String
            
        }
        
        // dataDic 中包含参数 streamName 推流地址 owner 主要的主播
        let dataDic: NSDictionary = ["streamName":"此处填写推流地址", "owner":1]
        // 字典转json 字符串
        let dataStr = getJSONStringFromDictionary(dictionary:dataDic)
        
        let code: Int32
        // **注意：同一个频道中，只能有一个主播，去传 dataStr，info有值，只有主播才可以维护合流界面布局
        if isOwner {
            code = rtcEngine.joinChannel(byKey: nil, channelName: roomName, info:dataStr, uid: 0, joinSuccess: nil)
        } else {
            // **注意：非主要的主播，则不传 dataStr，info无值
            code = rtcEngine.joinChannel(byKey: nil, channelName: roomName, info:nil, uid: 0, joinSuccess: nil)
        }
       

        if code == 0 {
            setIdleTimerActive(false)
            rtcEngine.setEnableSpeakerphone(true)
        } else {
            DispatchQueue.main.async(execute: {
                self.alert(string: "Join channel failed: \(code)")
            })
        }
        
        if isBroadcaster {
            shouldEnhancer = true
        }
    }
}

extension LiveRoomViewController: AgoraRtcEngineDelegate {
    
    /// 远端首帧视频接收解码回调
    ///
    /// - Parameters:
    ///   - engine: AgoraRtcEngineKit实例
    ///   - uid: 用户ID，指定是哪个用户的视频流
    ///   - size: 视频流尺寸（宽度和高度）
    ///   - elapsed: 加入频道开始到该回调触发的延迟（毫秒)
    func rtcEngine(_ engine: AgoraRtcEngineKit!, firstRemoteVideoDecodedOfUid uid: UInt, size: CGSize, elapsed: Int) {
        print("uid =========远端首帧视频接收解码回调=========\(uid)")
       
        let userSession = videoSession(ofUid: Int64(uid))
        rtcEngine.setupRemoteVideo(userSession.canvas)
    }
    
    
    /// 本地首帧视频显示回调
    ///
    /// - Parameters:
    ///   - engine: AgoraRtcEngineKit实例
    ///   - size: 视频流尺寸（宽度和高度）
    ///   - elapsed: 加入频道开始到该回调触发的延迟（毫秒)
    func rtcEngine(_ engine: AgoraRtcEngineKit!, firstLocalVideoFrameWith size: CGSize, elapsed: Int) {
        if let _ = videoSessions.first {
            updateInterface(withAnimation: false)
        }
    }
    
    
    // 获取当前时间 - 年月日时分秒星期
    func getTimes() -> [Int] {
        
        var timers: [Int] = [] //  返回的数组
        
        let calendar: Calendar = Calendar(identifier: .gregorian)
        var comps: DateComponents = DateComponents()
        comps = calendar.dateComponents([.year,.month,.day, .weekday, .hour, .minute,.second], from: Date())
        
        timers.append(comps.year! % 2000)  // 年 ，后2位数
        timers.append(comps.month!)            // 月
        timers.append(comps.day!)                // 日
        timers.append(comps.hour!)               // 小时
        timers.append(comps.minute!)            // 分钟
        timers.append(comps.second!)            // 秒
        timers.append(comps.weekday! - 1)      //星期
        
        return timers;
    }
    
    /// 用户离线回调
    ///
    /// - Parameters:
    ///   - engine:  AgoraRtcEngineKit实例
    ///   - uid: 用户ID
    ///   - reason: 离线原因： AgoraRtc_UserOffline_Quit：用户主动离开。 AgoraRtc_UserOffline_Dropped：因过长时间收不到对方数据包，超时掉线。注意：由于SDK使用的是不可靠通道，也有可能对方主动离开本方没收到对方离开消息而误判为超时掉线。 AgoraRtc_UserOffline_BecomeAudience：当用户身份从主播切换为观众时触发。
    func rtcEngine(_ engine: AgoraRtcEngineKit!, didOfflineOfUid uid: UInt, reason: AgoraRtcUserOfflineReason) {
        uidArray.remove(uid)
        
        print("离线时间 ----- \(getTimes())")
        print("uid ============其他用户离线回调============ \(uid)")
        layoutAgoraRtcVideoCompositing()
        
        var indexToDelete: Int?
        for (index, session) in videoSessions.enumerated() {
            if session.uid == Int64(uid) {
                indexToDelete = index
            }
        }
        
        if let indexToDelete = indexToDelete {
            let deletedSession = videoSessions.remove(at: indexToDelete)
            deletedSession.hostingView.removeFromSuperview()
            
            if deletedSession == fullSession {
                fullSession = nil
            }
        }
        
        
    
    }
    
    
    /// 加入频道成功回调
    ///
    /// - Parameters:
    ///   - engine: AgoraRtcEngineKit 实例
    ///   - channel: 频道名
    ///   - uid: 用户ID
    ///   - elapsed: 从joinChannel开始到该事件产生的延迟（毫秒）
    func rtcEngine(_ engine: AgoraRtcEngineKit!, didJoinChannel channel: String!, withUid uid: UInt, elapsed: Int) {
        myUid = uid
        uidArray.addObjects(from: [uid])
        print("uidArray first ---- \(uidArray)")

        print("\(channel)")
        
        print("uid ============ 本设备用户加入频道成功回调============ \(uid)")
        // 本设备用户为主播 则可以设置合流界面
        if isBroadcaster {
            layoutAgoraRtcVideoCompositing()
        }
    }
    
    
    /// 重新加入频道回调
    ///
    /// - Parameters:
    ///   - engine: AgoraRtcEngineKit实例
    ///   - channel: 频道名
    ///   - uid: 用户ID
    ///   - elapsed: 从joinChannel开始到该事件产生的延迟（毫秒）
    func rtcEngine(_ engine: AgoraRtcEngineKit!, didRejoinChannel channel: String!, withUid uid: UInt, elapsed: Int) {
        print("uid ============重新加入频道回调============ \(uid)")

    }
    
    
    /// 用户加入回调
    ///
    /// - Parameters:
    ///   - engine: AgoraRtcEngineKit实例
    ///   - uid: 用户ID
    ///   - elapsed: 加入频道开始到该回调触发的延迟
    func rtcEngine(_ engine: AgoraRtcEngineKit!, didJoinedOfUid uid: UInt, elapsed: Int) {
        uidArray.addObjects(from: [uid])
        print("uidArray addObjects ---- \(uidArray)")

        print("uid ============其他用户加入回调============ \(uid)")
        
        layoutAgoraRtcVideoCompositing()
    }
    
    // 设置 画中画布局
    func layoutAgoraRtcVideoCompositing() {

        print("uidArray ---- \(uidArray)")
        compositingLayout.canvasWidth = Int(UIScreen.main.bounds.size.width)
        compositingLayout.canvasHeight = Int(UIScreen.main.bounds.size.height)

        if uidArray.count == 1{
            var region = AgoraRtcVideoCompositingRegion();
            region.uid = uidArray.object(at: 0) as! UInt
            region.x = 0.0
            region.y = 0.0
            region.width = 1.0
            region.height = 1.0
            region.zOrder = 0
            region.alpha = 1.0
            
            let render = AgoraRtcRenderMode(rawValue: 2);
            region.renderMode = render!
            
            compositingLayout.regions = [region]
        }
        else if uidArray.count == 2{
            var region1 = AgoraRtcVideoCompositingRegion();
            region1.uid = uidArray.object(at: 0) as! UInt
            region1.x = 0.0
            region1.y = 0.0
            region1.width = 1.0
            region1.height = 0.5
            region1.zOrder = 0
            region1.alpha = 1.0
            
            var region2 = AgoraRtcVideoCompositingRegion();
            region2.uid = uidArray.object(at: 1) as! UInt
            region2.x = 0.0
            region2.y = 0.5
            region2.width = 1.0
            region2.height = 0.5
            region2.zOrder = 0
            region2.alpha = 1.0
            
            let render = AgoraRtcRenderMode(rawValue: 2);
            region1.renderMode = render!
            region2.renderMode = render!
            
            compositingLayout.regions = [region1, region2]
            
        } else if uidArray.count == 3{
            var region1 = AgoraRtcVideoCompositingRegion();
            region1.uid = uidArray.object(at: 0) as! UInt
            region1.x = 0.0
            region1.y = 0.0
            region1.width = 1
            region1.height = 0.5
            region1.zOrder = 0
            region1.alpha = 1.0
            
            var region2 = AgoraRtcVideoCompositingRegion();
            region2.uid = uidArray.object(at: 1) as! UInt
            region2.x = 0.0
            region2.y = 0.5
            region2.width = 0.5
            region2.height = 0.5
            region2.zOrder = 0
            region2.alpha = 1.0
            
            var region3 = AgoraRtcVideoCompositingRegion();
            region3.uid = uidArray.object(at: 2) as! UInt
            region3.x = 0.5
            region3.y = 0.5
            region3.width = 0.5
            region3.height = 0.5
            region3.zOrder = 0
            region3.alpha = 1.0
            
            let render = AgoraRtcRenderMode(rawValue: 2);
            region1.renderMode = render!
            region2.renderMode = render!
            region3.renderMode = render!
            
            compositingLayout.regions = [region1, region2, region3]
            
        } else if uidArray.count == 4{
            var region1 = AgoraRtcVideoCompositingRegion();
            region1.uid = uidArray.object(at: 0) as! UInt
            region1.x = 0.0
            region1.y = 0.0
            region1.width = 1.0
            region1.height = 1.0
            region1.zOrder = 0
            region1.alpha = 1.0
            
            var region2 = AgoraRtcVideoCompositingRegion();
            region2.uid = uidArray.object(at: 1) as! UInt
            region2.x = 0.03
            region2.y = 0.65
            region2.width = 0.3
            region2.height = 0.3
            region2.zOrder = 100
            region2.alpha = 1.0
            
            var region3 = AgoraRtcVideoCompositingRegion();
            region3.uid = uidArray.object(at: 2) as! UInt
            region3.x = 0.35
            region3.y = 0.65
            region3.width = 0.3
            region3.height = 0.3
            region3.zOrder = 100
            region3.alpha = 1.0
            
            var region4 = AgoraRtcVideoCompositingRegion();
            region4.uid = uidArray.object(at: 3) as! UInt
            region4.x = 0.67
            region4.y = 0.65
            region4.width = 0.3
            region4.height = 0.3
            region4.zOrder = 100
            region4.alpha = 1.0
            
            let render = AgoraRtcRenderMode(rawValue: 2);
            region1.renderMode = render!
            region2.renderMode = render!
            region3.renderMode = render!
            region4.renderMode = render!
            
            compositingLayout.regions = [region1, region2, region3, region4]
        }
        // 应用程序需保证同一频道内仅有一人调用该方法，如果同一频道内有多人调用该方法，其他调用了该方法的用户需调用 clearVideoCompositingLayout 取消已设置的画中画布局，仅留一人保留布局设置
        rtcEngine.clearVideoCompositingLayout()
        print("compositingLayout.regions ---- \(compositingLayout.regions)")
        rtcEngine.setVideoCompositingLayout(compositingLayout)

    }
    
    
    
    /// 音量提示回调
    ///
    /// - Parameters:
    ///   - engine: AgoraRtcEngineKit实例
    ///   - speakers: 说话者（数组）。每个speaker()： uid: 说话者的用户ID; volume: 说话者的音量（0~255）
    ///   - totalVolume: （混音后的）总音量（0~255）
    func rtcEngine(_ engine: AgoraRtcEngineKit!, reportAudioVolumeIndicationOfSpeakers speakers: [Any]!, totalVolume: Int) {
        print("uid ============音量提示回调============ \(speakers)")

    }
    
    
    /// 用户音频静音回调
    ///
    /// - Parameters:
    ///   - engine: AgoraRtcEngineKit实例
    ///   - muted: Yes: 已静音; No: 已取消静音
    ///   - uid: 用户ID
    func rtcEngine(_ engine: AgoraRtcEngineKit!, didAudioMuted muted: Bool, byUid uid: UInt) {
        print("uid ============用户音频静音回调============ \(uid)")

    }
    
    
    /// 用户停止/重新发送视频回调
    ///
    /// - Parameters:
    ///   - engine: AgoraRtcEngineKit实例
    ///   - muted: Yes: 该用户已暂停发送其视频流; No: 该用户已恢复发送其视频流
    ///   - uid: 用户ID
    func rtcEngine(_ engine: AgoraRtcEngineKit!, didVideoMuted muted: Bool, byUid uid: UInt) {
        print("uid ============用户停止/重新发送视频回调============ \(uid)")

    }
    
    
    /// 语音路由已变更回调
    ///
    /// - Parameters:
    ///   - engine: AgoraRtcEngineKit实例
    ///   - routing: 语音路由状态
    func rtcEngine(_ engine: AgoraRtcEngineKit!, didAudioRouteChanged routing: AudioOutputRouting) {

    }
    
    
    /// 用户启用/关闭视频回调
    ///
    /// - Parameters:
    ///   - engine: AgoraRtcEngineKit实例
    ///   - enabled: Yes: 该用户已启用了视频功能; No: 该用户已关闭了视频功能
    ///   - uid: 用户ID
    func rtcEngine(_ engine: AgoraRtcEngineKit!, didVideoEnabled enabled: Bool, byUid uid: UInt) {
        print("uid ============用户启用/关闭视频回调============ \(uid)")

    }
    
    // 摄像头启用回调
    func rtcEngineCameraDidReady(_ engine: AgoraRtcEngineKit!) {
        print(" ============摄像头启用回调============ ")

    }
    // 视频功能停止回调
    func rtcEngineVideoDidStop(_ engine: AgoraRtcEngineKit!) {
        print(" ============视频功能停止回调============ ")
    }
    // 网络连接中断回调
    func rtcEngineConnectionDidInterrupted(_ engine: AgoraRtcEngineKit!) {
        print(" ============网络连接中断回调============ ")
    }
    // 网络连接丢失回调
    func rtcEngineConnectionDidLost(_ engine: AgoraRtcEngineKit!) {
        print(" ============网络连接丢失回调============ ")
    }
    
    
    
    /// 发生警告回调
    ///
    /// - Parameters:
    ///   - engine: AgoraRtcEngineKit实例
    ///   - warningCode: 警告代码
    func rtcEngine(_ engine: AgoraRtcEngineKit!, didOccurWarning warningCode: AgoraRtcWarningCode) {
        print(" ============ 发生警告回调 ============ \(warningCode)")

    }
    
    
    /// 发生错误回调
    ///
    /// - Parameters:
    ///   - engine: AgoraRtcEngineKit实例
    ///   - errorCode: 错误代码
    func rtcEngine(_ engine: AgoraRtcEngineKit!, didOccurError errorCode: AgoraRtcErrorCode) {
        print(" ============ 发生错误回调 ============ ")

    }
    
}
