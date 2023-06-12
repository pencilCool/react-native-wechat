#import <React/RCTConvert.h>
#import <React/RCTUtils.h>
#import <React/RCTLog.h>

#import "WXApi.h"
#import "RNLWeChat.h"
#import "RNLWeChatAPIDelegate.h"
#import "RNLWeChatReq.h"
#import "RNLWeChatResp.h"

#define WX_SendReq(ReqClass) \
[WXApi sendReq:req completion:^(BOOL success) { \
if(success){  \
[self addResponseHandleWithName:NSStringFromClass([ReqClass class])  \
andResolver:resolve  \
andRejecter:reject];  \
} else {  \
reject(RNLWeChatGetErrorCode(RNLWeChatInvokeFailedError),  \
@"Open business view request failed.", nil);  \
}  \
}];

static NSString* RNLWeChatGetErrorCode(RNLWeChatError error) {
    return [NSString stringWithFormat:@"%ld", (long)error];
}

@interface RNLWeChat () <RNLWeChatAPIReceiver>

- (void)addResponseHandleWithName:(NSString *)aName andResolver:(RCTPromiseResolveBlock)resolve andRejecter:(RCTPromiseRejectBlock)reject;

- (void)removeResponseHandleByName:(NSString *)aName;

@end

@implementation RNLWeChat {
    RNLWeChatAPIDelegate *mWeChatAPIDelegate;
    NSMutableDictionary *mResponseHandle;
    BOOL isListeningWeChatRequest;
    NSMutableArray *mPendingRequests;
}

static NSString *const kOpenURLNotification = @"RCTOpenURLNotification";

- (instancetype)init
{
    self = [super init];
    if (self) {
        mWeChatAPIDelegate = [RNLWeChatAPIDelegate new];
        __weak RNLWeChat *weakSelf = self;
        [mWeChatAPIDelegate setReceiverDelegate:weakSelf];
        mResponseHandle = [NSMutableDictionary new];
        mPendingRequests = [NSMutableArray new];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleOpenURLNotification:)
                                                     name:kOpenURLNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - export methods

#pragma mark - initialize
RCT_REMAP_METHOD(initialize,
                 initializeWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    BOOL debug = [RCTConvert BOOL:option[@"debug"]];
    if (debug) {
        [WXApi startLogByLevel:WXLogLevelDetail logBlock:^(NSString * _Nonnull log) {
            RCTLogInfo(@"RNLWeChat %@", log);
        }];
    } else {
        [WXApi stopLog];
    }
    
    
//    [WXApi registerApp:appID enableMTA:NO]
    
    NSString *appID = [RCTConvert NSString:option[@"appID"]];
    if ([WXApi registerApp:appID universalLink:@""]) {
        resolve(nil);
    } else {
        reject(RNLWeChatGetErrorCode(RNLWeChatInvokeFailedError),
               @"APP register failed.", nil);
    }
}

#pragma mark - isAppInstalled
RCT_REMAP_METHOD(isAppInstalled,
                 isAppInstalledWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        resolve([NSNumber numberWithBool:[WXApi isWXAppInstalled]]);
    });
}

#pragma mark - getAppInstallUrl
RCT_REMAP_METHOD(getAppInstallUrl,
                 getAppInstallUrlWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    resolve([WXApi getWXAppInstallUrl]);
}

#pragma mark - openApp
RCT_REMAP_METHOD(openApp,
                 openAppWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([WXApi openWXApp]) {
            resolve(nil);
        } else {
            reject(RNLWeChatGetErrorCode(RNLWeChatInvokeFailedError),
                   @"Open APP failed.", nil);
        }
    });
}

#pragma mark - isSupportOpenApi
RCT_REMAP_METHOD(isSupportOpenApi,
                 isSupportOpenApiWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        resolve([NSNumber numberWithBool:[WXApi isWXAppSupportApi]]);
    });
}

#pragma mark - getSDKVersion
RCT_REMAP_METHOD(getSDKVersion,
                 getApiVersionWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    resolve([WXApi getApiVersion]);
}

#pragma mark - auth
RCT_REMAP_METHOD(auth,
                 authWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    SendAuthReq *req = [RNLWeChatReq getSendAuthReqWithOption:option];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL aResult;
        if([RCTConvert BOOL:option[@"fallback"]]) {
            UIViewController *controller = RCTPresentedViewController();
            if (controller) {
                [WXApi sendAuthReq:req viewController:controller delegate:mWeChatAPIDelegate completion:^(BOOL success) {
                    if(success) {
                        [self addResponseHandleWithName:NSStringFromClass([SendAuthReq class])
                                            andResolver:resolve
                                            andRejecter:reject];
                    } else {
                        reject(RNLWeChatGetErrorCode(RNLWeChatInvokeFailedError),
                               @"Root view controller isn't exist.", nil);
                    }
                }];
            } else {
                reject(RNLWeChatGetErrorCode(RNLWeChatInvokeFailedError),
                       @"Root view controller isn't exist.", nil);
                return;
            }
        } else {
            WX_SendReq(SendAuthReq);
        }
       
    });
}

#pragma mark - pay
RCT_REMAP_METHOD(pay,
                 payWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    PayReq *req = [RNLWeChatReq getPayReqWithOption:option];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WX_SendReq(PayReq);
    });
}

#pragma mark - offlinePay
RCT_REMAP_METHOD(offlinePay,
                 offlinePayWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    WXOfflinePayReq *req = [RNLWeChatReq getWXOfflinePayReqWithOption:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WX_SendReq(WXOfflinePayReq);
    });
}

#pragma mark - nontaxPay
RCT_REMAP_METHOD(nontaxPay,
                 nontaxPayWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    WXNontaxPayReq *req = [RNLWeChatReq getWXNontaxPayReqWithOption:option];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WX_SendReq(WXNontaxPayReq);
    });
}

#pragma mark - payInsurance
RCT_REMAP_METHOD(payInsurance,
                 payInsuranceWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    WXPayInsuranceReq *req = [RNLWeChatReq getWXPayInsuranceReqWithOption:option];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WX_SendReq(WXPayInsuranceReq);
    });
}


#pragma mark - openRankList
RCT_REMAP_METHOD(openRankList,
                 openRankListWithResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    OpenRankListReq *req = [RNLWeChatReq getOpenRankListReqWithOption:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WX_SendReq(OpenRankListReq);
    });
}

#pragma mark - openWebView
RCT_REMAP_METHOD(openWebView,
                 openWebViewWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    OpenWebviewReq *req = [RNLWeChatReq getOpenWebViewReqWithOption:option];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WX_SendReq(OpenWebviewReq);
    });
}

#pragma mark - openBusinessView
RCT_REMAP_METHOD(openBusinessView,
                 openBusinessViewWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    WXOpenBusinessViewReq *req = [RNLWeChatReq getWXOpenBusinessViewReqWithOption:option];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WX_SendReq(WXOpenBusinessViewReq);
    });
}

#pragma mark - openBusinessWebView
RCT_REMAP_METHOD(openBusinessWebView,
                 openBusinessWebViewWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    WXOpenBusinessWebViewReq *req = [RNLWeChatReq getWXOpenBusinessWebViewReqWithOption:option];
    
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WX_SendReq(WXOpenBusinessWebViewReq);
    });
}

#pragma mark - addCard
RCT_REMAP_METHOD(addCard,
                 addCardWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    AddCardToWXCardPackageReq *req = [RNLWeChatReq getAddCardToWXCardPackageReqWithOption:option];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WX_SendReq(AddCardToWXCardPackageReq);
    });
}

#pragma mark - chooseCard
RCT_REMAP_METHOD(chooseCard,
                 chooseCardWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    WXChooseCardReq *req = [RNLWeChatReq getWXChooseCardReqWithOption:option];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WX_SendReq(WXChooseCardReq);
    });
}

#pragma mark - chooseInvoice
RCT_REMAP_METHOD(chooseInvoice,
                 chooseInvoiceWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    WXChooseInvoiceReq *req = [RNLWeChatReq getWXChooseInvoiceReqWithOption:option];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WX_SendReq(WXChooseInvoiceReq)
    });
}

#pragma mark - invoiceAuthInsert
RCT_REMAP_METHOD(invoiceAuthInsert,
                 invoiceAuthInsertWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    WXInvoiceAuthInsertReq *req = [RNLWeChatReq getWXInvoiceAuthInsertReqWithOption:option];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WX_SendReq(WXInvoiceAuthInsertReq);
    });
}

#pragma mark - launchMiniProgram
RCT_REMAP_METHOD(launchMiniProgram,
                 launchMiniProgramWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    WXLaunchMiniProgramReq *req = [RNLWeChatReq getWXLaunchMiniProgramReqWithOption:option];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WX_SendReq(WXLaunchMiniProgramReq);
    });
}

#pragma mark - subscribeMiniProgramMessage
RCT_REMAP_METHOD(subscribeMiniProgramMessage,
                 subscribeMiniProgramMessageWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    WXSubscribeMiniProgramMsgReq *req = [RNLWeChatReq getWXSubscribeMiniProgramMsgReqWithOption:option];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WX_SendReq(WXSubscribeMiniProgramMsgReq);
    });
}

#pragma mark - sendMessage
RCT_REMAP_METHOD(sendMessage,
                 sendMessageWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        SendMessageToWXReq *req = [RNLWeChatReq getSendMessageToWXReqWithOption:option];
        WX_SendReq(SendMessageToWXReq);
    });
}

#pragma mark - subscribeMessage
RCT_REMAP_METHOD(subscribeMessage,
                 subscribeMessageWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    WXSubscribeMsgReq *req = [RNLWeChatReq getWXSubscribeMsgReqWithOption:option];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        WX_SendReq(WXSubscribeMsgReq);
    });
}

#pragma mark - sendMessageResp
RCT_REMAP_METHOD(sendMessageResp,
                 sendMessageRespWithOption:(NSDictionary *)option
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        GetMessageFromWXResp *resp = [RNLWeChatResp getGetMessageFromWXRespWithOption:option];
        [WXApi sendResp:resp completion:^(BOOL success) {
            if(success) {
                
                resolve(nil);
            } else {
                reject(RNLWeChatGetErrorCode(RNLWeChatInvokeFailedError),
                       @"Send message response failed.", nil);
                
            }
        }];
    });
}

#pragma mark - showMessageResp
RCT_REMAP_METHOD(showMessageResp,
                 showMessageRespResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    ShowMessageFromWXResp *resp = [RNLWeChatResp getShowMessageFromWXRespWithOption:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [WXApi sendResp:resp completion:^(BOOL success) {
            if(!success) {
                reject(RNLWeChatGetErrorCode(RNLWeChatInvokeFailedError),
                       @"Show message response failed.", nil);
            } else {
                resolve(nil);
            }
        }];
    });
}

#pragma mark - listenRequest
RCT_REMAP_METHOD(listenRequest,
                 listenRequestRresolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    isListeningWeChatRequest = YES;
    if ([mPendingRequests count] > 0) {
        resolve(mPendingRequests);
        [mPendingRequests removeAllObjects];
    } else {
        resolve(nil);
    }
}

#pragma mark - stopListenRequest
RCT_REMAP_METHOD(stopListenRequest,
                 stopListenRequestRresolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    isListeningWeChatRequest = NO;
    resolve(nil);
}

#pragma mark - WeChat App request handle

static NSString* kWeChatRequestEventName = @"RNLWeChatRequestEvent";

- (void)onReqFromWeChatWithPayload:(NSDictionary *)aPayload
{
    dispatch_async(_methodQueue, ^{
        if (isListeningWeChatRequest) {
            [self sendEventWithName:kWeChatRequestEventName body:aPayload];
        } else {
            [mPendingRequests addObject:aPayload];
        }
    });
}

#pragma mark - WeChat App response handle

- (void)addResponseHandleWithName:(NSString *)aName andResolver:(RCTPromiseResolveBlock)resolve andRejecter:(RCTPromiseRejectBlock)reject
{
    mResponseHandle[aName] = @[resolve, reject];
}

- (void)removeResponseHandleByName:(NSString *)aName
{
    [mResponseHandle removeObjectForKey:aName];
}

- (void)onRespFromWeChatWithReqName:(NSString *)aName andSuccess:(BOOL)isSuccess andPayload:(NSDictionary *)aPayload
{
    if (mResponseHandle[aName]) {
        if (isSuccess) {
            RCTPromiseResolveBlock resolve = mResponseHandle[aName][0];
            if (resolve) {
                resolve(aPayload);
            }
        } else {
            RCTPromiseRejectBlock reject = mResponseHandle[aName][1];
            if (reject) {
                reject(aPayload[@"errorCode"],
                       RCTJSONStringify(aPayload, nil), nil);
            }
        }
        [self removeResponseHandleByName:aName];
    }
}

#pragma mark - notification observer

- (void)handleOpenURLNotification:(NSNotification *)notification
{
    NSDictionary *info = [notification userInfo];
    if (info && info[@"url"]) {
        [WXApi handleOpenURL:[NSURL URLWithString:info[@"url"]]
                    delegate:mWeChatAPIDelegate];
    }
}

#pragma mark - Bridge

RCT_EXPORT_MODULE(RNLWeChat)

+ (BOOL)requiresMainQueueSetup
{
    return NO;
}

@synthesize methodQueue = _methodQueue;

- (NSArray<NSString *> *)supportedEvents
{
    return @[kWeChatRequestEventName];
}

@end
