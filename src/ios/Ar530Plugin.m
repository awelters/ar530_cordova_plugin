/*
 Ar530Plugin.m
 Uses Ar530 SDK
 */

#import "Ar530Plugin.h"

BOOL isOpen = NO ;
int scanPeriod = 1000;
char uid[128] = {0};

@implementation Ar530Plugin

/** Initialise the plugin */
- (void)init:(CDVInvokedUrlCommand*)command {
    if (!_ar530) {
        // Initialise ar530SDK
        _ar530 = [FTaR530 sharedInstance];
        [_ar530 setDeviceEventDelegate:self];
        // set the card type
        Byte cardType = 0;
        cardType |= A_CARD;
        cardType |= B_CARD;
        cardType |= Felica_CARD;
        cardType |= Topaz_CARD;

        _ar530.cardType = cardType;
    }

    [self openCard];
}

- (void)setConfiguration:(CDVInvokedUrlCommand*)command {
    NSString* callbackId = command.callbackId;
    NSString* periodString = [command.arguments objectAtIndex:0];

    periodString = [periodString stringByReplacingOccurrencesOfString:@" " withString:@""];  // remove whitespace
    if ([[periodString lowercaseString] isEqualToString:@"unchanged"]){
        return;
    }
    int period = [periodString intValue];
    if (period > 0) {
        scanPeriod = period;
    } else {
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Scan period must be > 0"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
    }
}

- (void)setTagDiscoveredCallback:(CDVInvokedUrlCommand*)command
{
    didFindTagWithUidCallbackId = command.callbackId;
}

#pragma mark --Internal Methods--

-(void)clearTimer {
    if ([self.timer isValid]) {
        [self.timer invalidate];
    }
    self.timer=nil;
}

-(void)poll {
    double scanPeriodInSecs = scanPeriod / 1000.0;
    self.timer = [NSTimer scheduledTimerWithTimeInterval: scanPeriodInSecs
                                                  target: self
                                                selector: @selector(openCard)
                                                userInfo: nil
                                                 repeats: NO];
}

-(void)openCard
{
    [self clearTimer];
    dispatch_async(dispatch_get_main_queue(), ^(void){
        // Here we need waiting until the device has initialized
        [NSThread sleepForTimeInterval:2.5f] ;
        [_ar530 NFC_Card_Open:self];
    });
}


-(void)getOpenResult:(nfc_card_t)cardHandle
{
    if(cardHandle != 0) {
        NSLog(@"FT_FUNCTION_NUM_OPEN_CARD success!");
        char newUid[128] = {0};
        HexToStr(newUid, cardHandle->uid, cardHandle->uidLen);
        isOpen = YES ;

        NSLog(@"FT_FUNCTION_NUM_OPEN_CARD Found tag UID: %@", uid);

        //only if a new uid do we dispatch found tag
        if(strcmp(newUid, uid) != 0) {
            NSLog(@"FT_FUNCTION_NUM_OPEN_CARD Found NEW tag");

            memset(uid, '\0', sizeof(uid));
            strcpy(uid, newUid);

            // send tag read update to Cordova
            if (didFindTagWithUidCallbackId) {
                NSArray* result = @[uid];
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsMultipart:result];
                [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:didFindTagWithUidCallbackId];
            }
        }

    }
    else{
        NSLog(@"FT_FUNCTION_NUM_OPEN_CARD failed!");
    }
    [self poll];
}

#pragma mark - aR530 Delegates

- (void)FTaR530DidConnected{

    NSLog(@"R connected") ;
    if(isOpen == YES){
        return ;
    }

    [self openCard];
}

- (void)FTaR530DidDisconnected{
    [self clearTimer];

    NSLog(@"R disconnect") ;

    //release
    if (isOpen == NO) {
        return ;
    }
    isOpen = NO ;
    memset(uid, '\0', sizeof(uid));
}

- (void)FTaR530GetInfoDidComplete:(unsigned char *)retData retDataLen:(unsigned int)retDataLen functionNum:(unsigned int)functionNum errCode:(unsigned int)errCode
{

}

- (void)FTNFCDidComplete:(nfc_card_t)cardHandle retData:(unsigned char *)retData retDataLen:(unsigned int)retDataLen functionNum:(unsigned int)funcNum errCode:(unsigned int)errCode
{
    switch (funcNum) {
        case FT_FUNCTION_NUM_OPEN_CARD:{
            NSLog(@"FT_FUNCTION_NUM_OPEN_CARD") ;
            [self getOpenResult:cardHandle];
            break;
        }
        default:
            break;
    }
}

@end
