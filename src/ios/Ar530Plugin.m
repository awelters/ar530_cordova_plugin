/*

 Ar530Plugin.m
 Uses Ar530 SDK
 */



#import "Ar530Plugin.h"


BOOL isOpen = NO ;
BOOL isPolling = NO;
char uid[128] = {0};

@implementation Ar530Plugin

/** Initialise the plugin */
- (void)init:(CDVInvokedUrlCommand*)command {

    if (!_ar530) {
        NSString* shouldPollString = [command.arguments objectAtIndex:0];
        int shouldPoll = [shouldPollString intValue];

        if (shouldPoll == 0) {
            isPolling = NO;
        } else {
            isPolling = YES;
        }

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

        [self startReading];
    }

}

- (void)scanForTag:(CDVInvokedUrlCommand*)command {

    if(isPolling == NO) {
        isPolling = YES;
        [self poll];
        isPolling = NO;
    }

}

- (void)setTagDiscoveredCallback:(CDVInvokedUrlCommand*)command
{
    didFindTagWithUidCallbackId = command.callbackId;
}


#pragma mark --Internal Methods--

-(void)poll {

    if( isOpen == YES && isPolling == YES ) {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [self openCard];
        });
    }

}

-(void)startReading
{

    dispatch_async(dispatch_get_main_queue(), ^(void){
        // Here we need waiting until the device has initialized
        [NSThread sleepForTimeInterval:2.5f] ;
        isOpen = YES ;
        [self poll];
    });

}

-(void)openCard
{
    [_ar530 NFC_Card_Open:self];
}

-(void)getOpenResult:(nfc_card_t)cardHandle
{

    if(cardHandle != 0) {
        NSLog(@"FT_FUNCTION_NUM_OPEN_CARD success!");
        char newUid[128] = {0};
        HexToStr(newUid, cardHandle->uid, cardHandle->uidLen);
        isOpen = YES ;

        NSLog(@"FT_FUNCTION_NUM_OPEN_CARD Found tag UID: %s", newUid);

        memset(uid, '\0', sizeof(uid));
        strcpy(uid, newUid);

        // send tag read update to Cordova
        if (didFindTagWithUidCallbackId) {
            NSString *str = [NSString stringWithFormat:@"%s", uid];
            NSArray* result = @[str];
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsMultipart:result];
            [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:didFindTagWithUidCallbackId];
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

    [self startReading];

}

- (void)FTaR530DidDisconnected{

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
            NSLog(@"FT_FUNCTION_NUM_OPEN_CARD %d",errCode) ;
            [self getOpenResult:cardHandle];
            break;
        }
        default:
            break;
    }

}

@end