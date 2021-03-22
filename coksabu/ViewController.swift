//
//  ViewController.swift
//  coksabu
//
//  Created by Yojic Jung on 2021/02/12.
//

import UIKit
import WebKit
import Foundation
import Gifu


class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
// WKUIDelegat: JavaScript, 기타플러그인 컨텐츠 이벤트를 캐피하여 동작, 웹 페이지 기본 UI 요소 제공
// WKNavigationDelegate : 프로토콜로 페이지의 start,loading,finish,error의 트리거 이벤트를 캐치하여 사용자 정의 동작 구현가능
// WKScriptMessageHandler : 프로토콜로 웹 페이지에서 실행되는 JavaScript Message를 수신하는 방법을 제공. 웹페이지에서 스크립트
//                          메세지가 수신될때 호출되는 userContentController를 정의하고 있다.
    
    var startTime: Date?
    var email : String?
    
    var priorEmail: String? = "noneEmail"
    var priorApnToken: String? = "noneApnToken"
    
    static var badgeCount:Int = 0
    
    @IBOutlet var webView: WKWebView!
    @IBOutlet var loadingPage: UIImageView!
    @IBOutlet var spinner: GIFImageView!
    
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        loadWebPage("https://m.coksabu.com")
            
        //백그라운드로 전활될때 실행되는 함수
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { (Notification) in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies({
                (cookies) in
                
                //이메일 존재 여부 알기 위해서
                var hasEmail:Bool = false
                
                //로그인 안된 최초의 상태에서도 쿠키는 존재함
                for cookie in cookies{
                    //로그인한 상태, 이메일이 존재함
                    if(cookie.name == "userInputEmail"){
                        hasEmail=true
                        self.email = cookie.value
                        NSLog("WKWebsiteDataStore cookie : \(cookie.name) \\ \(cookie.value)")
                    
                        // 이메일 또는 토큰이 달라지는 경우에는 서버에서 새로 등록 요청보냄, 앱 처음 구동시에도 보냄
                        if(self.priorEmail != self.email || self.priorApnToken != AppDelegate.apnToken){
                            self.jsonPost(AppDelegate.apnToken!, email: self.email!, emailTokenChange: "change")
                            
                        //이메일 또는 토큰이 달라지지 않았기 때문에 서버에서 이메일 토큰 새롭게 등록하지 않고 배지값만 가져옴
                        }else{
                            self.jsonPost(AppDelegate.apnToken!, email: self.email!, emailTokenChange: "noChange")
                        }
                        self.priorEmail = cookie.value
                        self.priorApnToken = AppDelegate.apnToken
                        
                    }
                }
                
                //로그아웃 상태
                if(hasEmail == false){
                    UIApplication.shared.applicationIconBadgeNumber = 0
                }else{
                //로그인상태
                    //jsonPost()메서드가 비동기로 실행되서 jsonPost()가 badgeCount를 처리 하는데 시간이 필요함
                    Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { (Timer) in
                        UIApplication.shared.applicationIconBadgeNumber = ViewController.badgeCount
                    }
                }
                hasEmail=false
            })
        }
        
        //백그라운드에서 포그라운드로 전환되면 실행되는 함수
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { (Notification) in
               
            let userDefault = UserDefaults.standard
            let pushUrl:String? = userDefault.string(forKey: "PUSH_URL")
            
            //링크가 있는 푸시를 클릭하는 경우에만 실행
            if(pushUrl != nil){
                self.spinnerON()
                NSLog(pushUrl!)
                NSLog("푸시에서 전달받은 웹뷰로")
                let myUrl = URL(string: pushUrl!)
                let myRequest = URLRequest(url: myUrl!)
                self.webView.load(myRequest)
                userDefault.removeObject(forKey: "PUSH_URL")
                userDefault.synchronize()
            }
        }
    }
    
    //웹뷰가 시작될때
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        startTime = Date()
    }
    
    //웹뷰가 로드완료되면
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let endTime = Date()
        let timeInterval = endTime.timeIntervalSince(startTime!)
        
        //웹뷰 로드 완료시간이 1.5초를 넘지 않으면 로딩화면을 2초 더 추가로 보여주기 위해서
        if(timeInterval<1.5){
            Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { (Timer) in
                self.loadingPage.image = nil
            }
        }else{
            self.loadingPage.image = nil
            
        }
        
        self.spinner.stopAnimatingGIF()
        self.spinner.removeFromSuperview()
    }
    
    
    //WKUIDelegate의 자바스크립트와 관련된 트리거 이벤트를 케치하는 함수
    //웹의 alert창을 앱상에서 제어하기 위한 메소드
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
            
            //alert창 다이얼로그 제어
            alertController.addAction(UIAlertAction(title: "확인", style: .default, handler: {(action) in
                completionHandler()
            }))
            
            self.present(alertController, animated: true, completion: nil)
        }
    
    
    
    //웹의 confirm창을 앱상에서 제어하기 위한 메소드
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alertController = UIAlertController(title: "", message: message, preferredStyle: .alert)
            
            //confirm창 다일로그 제어
            alertController.addAction(UIAlertAction(title: "확인", style: .default, handler: { (action) in
                completionHandler(true)
            }))
        
            //confirm창 다일로그 제어
            alertController.addAction(UIAlertAction(title: "취소", style: .default, handler: { (action) in
                completionHandler(false)
            }))
            
            self.present(alertController, animated: true, completion: nil)
        }
    
    //웹의 confirm창을 앱상에서 제어하기 위한 메소드
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            let alertController = UIAlertController(title: "", message: prompt, preferredStyle: .alert)
            
            alertController.addTextField { (textField) in
                textField.text = defaultText
            }
            
            //prompt창 다일로그 제어
            alertController.addAction(UIAlertAction(title: "확인", style: .default, handler: { (action) in
                if let text = alertController.textFields?.first?.text {
                    completionHandler(text)
                } else {
                    completionHandler(defaultText)
                }
            }))

            //prompt창 다일로그 제어
            alertController.addAction(UIAlertAction(title: "취소", style: .default, handler: { (action) in
                completionHandler(nil)
            }))

            self.present(alertController, animated: true, completion: nil)
        }
    
    ///WKNavigationDelegate 중복적으로 리로드 방지 (iOS 9 이후지원)
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
           webView.reload()
       }
    
    //뷰가 완전히 화면에 나타났을때 실행되는 함수
    override func viewDidAppear(_ animated: Bool) {
           super.viewDidAppear(true)
           checkNetworkConnect()
       }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    

    
    //네트워크 연결이 안되어있을시 앱 종료
    func checkNetworkConnect(){
            ///Alert를 사용한 Network의 Check는 viewDidAppear에서 수행
            if ReachAbility.isConnectedToNetwork(){
               //네트워크 정상작동시 아무것도 하지 않음
                
            } else{
                //네트워크 접속 안될시 경고창 띄우고 앱종료
                let networkCheckAlert = UIAlertController(title: "Network ERROR", message: "앱을 종료합니다.", preferredStyle: UIAlertController.Style.alert)
                
                networkCheckAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action: UIAlertAction!) in
                    print("App exit")
                    
                    exit(0)
                }))
                self.present(networkCheckAlert, animated: true, completion: nil)
            }
        }
    
    //스피너 작동
    func spinnerON(){
        self.spinner = GIFImageView(frame: CGRect(x: (self.view.bounds.width/2)-50, y: (self.view.bounds.height/2)-50, width: 100, height: 100))
        self.spinner.animate(withGIFNamed: "pushSpinner", animationBlock: {})
        self.view.addSubview(self.spinner)
    }
    
    
    func jsonPost(_ token: String, email: String, emailTokenChange: String) {
      // 1. 전송할 값 준비
      let param = ["token": token, "email" : email, "emailTokenChange": emailTokenChange] // JSON 객체로 변환할 딕셔너리 준비
      let paramData = try! JSONSerialization.data(withJSONObject: param, options: [])
     
      // 2. URL 객체 정의
      let url = URL(string: "https://coksabu.com/giveToIOS")
     
      // 3. URLRequest 객체 정의 및 요청 내용 담기
      var request = URLRequest(url: url!)
      request.httpMethod = "POST"
      request.httpBody = paramData
     
      // 4. HTTP 메시지에 포함될 헤더 설정
      request.addValue("applicaion/json", forHTTPHeaderField: "Content-Type")
      request.setValue(String(paramData.count), forHTTPHeaderField: "Content-Length")
    
      // 5. URLSession 객체를 통해 전송 및 응답값 처리 로직 작성
      let task = URLSession.shared.dataTask(with: request) {(data, response, error) in
                guard let data = data, error == nil else {// check for fundamental networking error
                   NSLog("error= \(String(describing: error))")
                   return
                }
                if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {// check for http errors
                   NSLog("statusCode should be 200, but is \(httpStatus.statusCode)")
                   NSLog("response =  \(String(describing: response))")
                }
        
                let responseString = String(data: data, encoding: .utf8)
                if(responseString != nil){
                    let responseStr = String(describing: responseString!).replacingOccurrences(of: "\"", with: "")
                    NSLog("responseString =  \(String(describing: responseString))")
                    let count = Int(responseStr)
                    print(count!)
                    ViewController.badgeCount = count!
                }
                
               
      }
      // 6. POST 전송
      task.resume()
    }
    
    func loadWebPage(_ url:String){
        let myUrl = URL(string: url)
        let myRequest = URLRequest(url: myUrl!)
        
       
        webView.backgroundColor = UIColor .clear
        webView.scrollView.bounces = false       //웹뷰의 스크롤 상단 끝 하단끝에 여백 안나타나게끔
        webView.scrollView.decelerationRate = .fast   //스크롤 속도 향상
        webView.uiDelegate = self
        webView.navigationDelegate = self
        //자바스크립트 허용
        //webView.configuration.preferences.javaScriptEnabled = true
        webView.allowsBackForwardNavigationGestures = true      //뒤로가기 허용
        //웹뷰의 userAgent에 APP_WISHROOM_IOS 이라는 문구를 넣어 ios 웹뷰로 들어오는 경로를 웹에서 파악할수 있게끔
        webView.evaluateJavaScript("navigator.userAgent"){(result, error) in
            
            let iosUserAgent = result as! String
            let agent = iosUserAgent + " APP_WISHROOM_IOS"
            self.webView.customUserAgent = agent
        }
        
        webView.load(myRequest)
        
        
    }
    

    
}
