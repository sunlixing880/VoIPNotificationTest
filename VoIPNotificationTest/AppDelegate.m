//
//  AppDelegate.m
//  VoIPNotificationTest
//
//  Created by chinaums on 2017/5/18.
//  Copyright © 2017年 chinaums. All rights reserved.
//

#import "AppDelegate.h"
#import "TTSConfig.h"
#import "PcmPlayer.h"
#import <PushKit/PushKit.h>
#import <iflyMSC/IFlyMSC.h>

@interface AppDelegate () <PKPushRegistryDelegate, IFlySpeechSynthesizerDelegate> {
    NSString *pcmSoundPath;
    NSString *wavSoundPath;
    NSString *soundContent;
    NSString *pcmSoundName;
    NSString *wavSoundName;
    PcmPlayer *_audioPlayer;
}

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    //注册推送通知(必须注册，否则本地推送无法生效)
    [self registerRemoteNotification];
    //注册VoIP通知
    [self registerVoIPNotification];
    //初始化讯飞SDK
    [self initIFlySetting];

    return YES;
}

- (void)registerRemoteNotification {
    UIUserNotificationType types = UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound;
    UIUserNotificationSettings *mySettings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:mySettings];
}

- (void)registerVoIPNotification {
    PKPushRegistry *voipRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    voipRegistry.delegate = self;
    voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
}

- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(PKPushType)type {
    NSString *str = [NSString stringWithFormat:@"%@",credentials.token];
    NSString *_tokenStr = [[[str stringByReplacingOccurrencesOfString:@"<" withString:@""]
                            stringByReplacingOccurrencesOfString:@">" withString:@""] stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSLog(@"VoIP token = %@", _tokenStr);
}

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type {
    NSDictionary *data = payload.dictionaryPayload;
    soundContent = data[@"aps"][@"alert"];
    
    NSString *soundDir = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, true) lastObject] stringByAppendingPathComponent:@"Sounds"];
    BOOL isDirExist = [[NSFileManager defaultManager] fileExistsAtPath:soundDir];
    if (!isDirExist) {
        [[NSFileManager defaultManager] createDirectoryAtPath:pcmSoundPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    pcmSoundName = @"notificationSound.pcm";
    wavSoundName = @"notificationSound.wav";
    pcmSoundPath = [NSString stringWithFormat:@"%@/%@", soundDir, pcmSoundName];
    wavSoundPath = [NSString stringWithFormat:@"%@/%@", soundDir, wavSoundName];
    [self generateSoundFile];
}

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type {
    NSLog(@"InvalidPushToken");
}

#pragma mark - IFlySpeechSynthesizerDelegate

- (void)initIFlySetting {
    //设置sdk的log等级，log保存在下面设置的工作路径中
//    [IFlySetting setLogFile:LVL_ALL];
    [IFlySetting setLogFile:LVL_NONE];
    
    //打开输出在console的log开关
//    [IFlySetting showLogcat:YES];
    [IFlySetting showLogcat:NO];
    
    //设置sdk的工作路径
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [paths objectAtIndex:0];
    [IFlySetting setLogFilePath:cachePath];
    
    //创建语音配置,appid必须要传入，仅执行一次则可
    NSString *initString = [[NSString alloc] initWithFormat:@"appid=%@",@"591a9e37"];
    
    //所有服务启动前，需要确保执行createUtility
    [IFlySpeechUtility createUtility:initString];
}

//根据文字生成音频文件，这里用的是讯飞的离线包，可以替换为其他方式
- (void)generateSoundFile {
    TTSConfig *instance = [TTSConfig sharedInstance];
    
    IFlySpeechSynthesizer *_iFlySpeechSynthesizer = [IFlySpeechSynthesizer sharedInstance];
    _iFlySpeechSynthesizer.delegate = self;
    
    //本地资源打包在app内
    NSString *resPath = [[NSBundle mainBundle] resourcePath];
    //本地demo本地发音人仅包含xiaoyan资源,由于auto模式为本地优先，为避免找不发音人错误，也限制为xiaoyan
    NSString *newResPath = [[NSString alloc] initWithFormat:@"%@/data/tts64res/common.jet;%@/data/tts64res/xiaoyan.jet",resPath,resPath];
    [[IFlySpeechUtility getUtility] setParameter:@"tts" forKey:[IFlyResourceUtil ENGINE_START]];
    [_iFlySpeechSynthesizer setParameter:newResPath forKey:@"tts_res_path"];
    
    //设置语速1-100
    [_iFlySpeechSynthesizer setParameter:instance.speed forKey:[IFlySpeechConstant SPEED]];
    
    //设置音量1-100
    [_iFlySpeechSynthesizer setParameter:instance.volume forKey:[IFlySpeechConstant VOLUME]];
    
    //设置音调1-100
    [_iFlySpeechSynthesizer setParameter:instance.pitch forKey:[IFlySpeechConstant PITCH]];
    
    //设置采样率
    [_iFlySpeechSynthesizer setParameter:instance.sampleRate forKey:[IFlySpeechConstant SAMPLE_RATE]];
    
    //设置发音人
    [_iFlySpeechSynthesizer setParameter:instance.vcnName forKey:[IFlySpeechConstant VOICE_NAME]];
    
    //设置文本编码格式
    [_iFlySpeechSynthesizer setParameter:@"unicode" forKey:[IFlySpeechConstant TEXT_ENCODING]];
    
    //设置引擎类型
    [_iFlySpeechSynthesizer setParameter:instance.engineType forKey:[IFlySpeechConstant ENGINE_TYPE]];
    
    [_iFlySpeechSynthesizer synthesize:soundContent toUri:pcmSoundPath];
    //[_iFlySpeechSynthesizer startSpeaking:soundText];
}

- (void)onCompleted:(IFlySpeechError *)error {
    NSLog(@"error = %@", error.errorDesc);
    
    NSData *pcmData = [NSData dataWithContentsOfFile:pcmSoundPath];
    if (pcmData) {
        NSData *wavData = [PcmPlayer convertPcmToWav:pcmData sampleRate:[[TTSConfig sharedInstance].sampleRate intValue]];
        BOOL writeResult = [wavData writeToFile:wavSoundPath atomically:YES];
        NSLog(@"write result = %i", writeResult);
    }
    else {
        return;
    }
    
    //弹出本地通知
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = soundContent;
    notification.soundName = wavSoundName;
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
    
    //播放wav音频
//    NSData *wavData = [NSData dataWithContentsOfFile:wavSoundPath];
//    _audioPlayer = [[PcmPlayer alloc] init];
//    [_audioPlayer writeWavData:wavData];
//    [_audioPlayer play];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
