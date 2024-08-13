//
//  ViewController.swift
//  RefreshableWebView
//
//  Created by 임훈사 on 8/13/24.
//

import UIKit
import WebKit
import Lottie

class ViewController: UIViewController, OnRefreshListener{
    private var webView: RefreshableWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let indicatorView = LottieAnimationView(name: "loading")
        indicatorView.frame.size = CGSize(width: 50, height: 50)
        indicatorView.loopMode = .loop
        indicatorView.play()
        self.view.addSubview(indicatorView)
        
        webView = RefreshableWebView(frame: view.bounds)
        webView.load(URLRequest(url: URL(string: "https://m.naver.com")!))
        self.view.addSubview(webView)
        
        let settings = RefreshSettings.Builder()
            .setRefreshingTime(0.5)
            .setRefreshThresholdPoint(200)
            .setOnRefreshListener(self)
            .setLoadingIndicatorView(indicatorView)
            .build()
        
        if let unwrappedSettings = settings {
            webView.setRefreshSettings(unwrappedSettings)
        }
    }
    
    func onRefresh(view: UIView) {
        webView.reload()
    }
}

class RefreshableWebView: WKWebView {
    private static let MOVE_THRESHOLD: CGFloat = 10
    private var dragStartY: CGFloat = 0
    private var lastContentOffsetY: CGFloat = 0
    private var settings: RefreshSettings?
    private var isRefreshEnabled: Bool = true
    private var isRefreshing: Bool = false
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
    }

    func setRefreshSettings(_ settings: RefreshSettings){
        self.settings = settings
        self.scrollView.delegate = self
        initLoadingIndicator(settings)
    }
    
    func setRefreshEnabled(_ enabled: Bool){
        self.isRefreshEnabled = enabled
    }
    
    private func initLoadingIndicator(_ settings: RefreshSettings){
        self.superview?.addSubview(settings.indicatorView)
    }
}

extension RefreshableWebView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if (isWebViewTopAndOverScroll(scrollView)) {
            settings?.indicatorView.isHidden = false
            settings?.indicatorView.frame.origin.y = moveDistanceToIndicatorY(scrollView)
        }
        
        self.lastContentOffsetY = scrollView.contentOffset.y
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.dragStartY = scrollView.contentOffset.y
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let currentY = scrollView.contentOffset.y
        
        if (isWebViewTop(currentY) && isOverRefreshThreshold(currentY)) {
            let refreshingTime = self.settings?.refreshingTime ?? 1.0
            
            isRefreshing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + refreshingTime) {
                self.settings?.listener.onRefresh(view: self)
                self.indicatorHideAnimation(duration: 0.5, endAction: {
                    self.isRefreshing = false
                })
            }
        }else{
            self.indicatorHideAnimation(duration: 0.2)
        }
    }
    
    private func isWebViewTopAndOverScroll(_ scrollView: UIScrollView) -> Bool {
        let currentY = scrollView.contentOffset.y
        return isWebViewTop(currentY) && isDownDrag(currentY) && isAbsolutelyMoved(currentY)
    }
    
    private func isWebViewTop(_ currentY: CGFloat) -> Bool {
        return currentY < 0
    }
    
    private func isDownDrag(_ currentY: CGFloat) -> Bool {
        return self.lastContentOffsetY < currentY
    }
    
    private func isAbsolutelyMoved(_ currentY: CGFloat) -> Bool {
        return ((abs(currentY) - abs(dragStartY)) > RefreshableWebView.MOVE_THRESHOLD)
    }
    
    private func isOverRefreshThreshold(_ currentY: CGFloat) -> Bool {
        return (abs(currentY) - abs(self.dragStartY)) > (settings?.refreshThresholdPoint ?? 0)
    }
    
    private func moveDistanceToIndicatorY(_ scrollView: UIScrollView) -> CGFloat {
        let distance = abs(scrollView.contentOffset.y) - abs(self.dragStartY)
        let indicatorMaxY = settings?.refreshThresholdPoint ?? 200
        
        return (distance * indicatorMaxY / self.frame.height) / 2
    }
    
    private func indicatorHideAnimation(duration: TimeInterval, endAction: (() -> Void)? = nil){
        let indicatorHeight = settings?.indicatorView.frame.height ?? 0
        
        UIView.animate(withDuration: duration, animations: {
            self.settings?.indicatorView.frame.origin.y = -indicatorHeight
        }, completion: { finished in
            endAction?()
        })
    }
}

class RefreshSettings {
    let listener: OnRefreshListener
    let indicatorView: UIView
    let refreshThresholdPoint: CGFloat
    let refreshingTime: TimeInterval

    private init(
        listener: OnRefreshListener,
        indicatorView: UIView,
        refreshThresholdPoint: CGFloat,
        refreshingTime: TimeInterval
    ) {
        self.listener = listener
        self.indicatorView = indicatorView
        self.refreshThresholdPoint = refreshThresholdPoint
        self.refreshingTime = refreshingTime
    }

    class Builder {
        private var listener: OnRefreshListener?
        private var indicatorView: UIView?
        private var refreshThresholdPoint: CGFloat = 200
        private var refreshingTime: TimeInterval = 2.0 // 2 seconds

        func setOnRefreshListener(_ listener: OnRefreshListener) -> Builder {
            self.listener = listener
            return self
        }

        func setLoadingIndicatorView(_ view: UIView) -> Builder {
            self.indicatorView = view
            return self
        }

        func setRefreshThresholdPoint(_ point: CGFloat) -> Builder {
            self.refreshThresholdPoint = point
            return self
        }

        func setRefreshingTime(_ duration: TimeInterval) -> Builder {
            self.refreshingTime = duration
            return self
        }

        func build() -> RefreshSettings? {
            guard let listener = listener, let indicatorView = indicatorView else {
                return nil
            }

            return RefreshSettings(
                listener: listener,
                indicatorView: indicatorView,
                refreshThresholdPoint: refreshThresholdPoint,
                refreshingTime: refreshingTime
            )
        }
    }
}

protocol OnRefreshListener: AnyObject {
    func onRefresh(view: UIView)
}
