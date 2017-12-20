/*

 Ar530Plugin.m

 Uses Ar530 SDK

 */



#import "Ar530Plugin.h"



BOOL isOpen = NO ;

BOOL isPolling = NO ;

int scanPeriod = 30000;



@implementation Ar530Plugin



/** Initialise the plugin */

- (void)init:(CDVInvokedUrlCommand*)command {

    if (!_ar530) {

        NSString* callbackId = command.callbackId;

        NSString* shouldPollString = [command.arguments objectAtIndex:0];

        NSString* periodString = [command.arguments objectAtIndex:1];



        int shouldPoll = [shouldPollString intValue];

        if (shouldPoll == 0) {

            isPolling = NO;

        } else {

            isPolling = YES;

        }



        int period = [periodString intValue];

        if (period == 0 || period >= 1000) {

            scanPeriod = period;

        } else {

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Scan period either must be turned off aka 0 or it must be >= 1000"];

            [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];

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

    if(isOpen == YES && isPolling == NO) {

        isPolling = YES;

        [self poll];

        isPolling = NO;

    }

}



- (void)setDeviceConnectedCallback:(CDVInvokedUrlCommand*)command

{

    deviceConnectedCallbackId = command.callbackId;

}



- (void)setTagDiscoveredCallback:(CDVInvokedUrlCommand*)command

{

    didFindTagWithUidCallbackId = command.callbackId;

}



#pragma mark --Internal Methods--



-(void)healthCheck {

    //timed out

    NSLog(@"healthCheck");



    //TODO: set the timer for 5 seconds and call getDeviceID, if the timer does not get reset in that time we are disconnected

    double scanPeriodInSecs = 5.0;

    _timer = [NSTimer scheduledTimerWithTimeInterval: scanPeriodInSecs

                                              target: self

                                            selector: @selector(FTaR530DidDisconnected)

                                            userInfo: nil

                                             repeats: NO];

    [ _ar530 getDeviceID:self];

}



-(void)startDeviceHealthCheck {

    if (scanPeriod > 0) {

        [self stopDeviceHealthCheck];

        NSLog(@"startDeviceHealthCheck");

        double scanPeriodInSecs = scanPeriod / 1000.0;

        _timer = [NSTimer scheduledTimerWithTimeInterval: scanPeriodInSecs

                                                  target: self

                                                selector: @selector(healthCheck)

                                                userInfo: nil

                                                 repeats: NO];

    }

}



-(void)stopDeviceHealthCheck {

    NSLog(@"stopDeviceHealthCheck");

    if ([_timer isValid]) {

        [_timer invalidate];

    }

    _timer=nil;

}



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

        [self startDeviceHealthCheck];

        [ _ar530 getDeviceID:self];

    });

}



-(void)connected:(int)yesOrNo

{

    NSLog(@"connected: %d", yesOrNo);



    // send tag read update to Cordova

    if (deviceConnectedCallbackId) {

        NSString *str = [NSString stringWithFormat:@"%d", yesOrNo];

        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:str];

        [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];

        [self.commandDelegate sendPluginResult:pluginResult callbackId:deviceConnectedCallbackId];

    }

}



-(void)openCard

{

    [_ar530 NFC_Card_Open:self];

}





-(void)getOpenResult:(nfc_card_t)cardHandle

{

    if(cardHandle != 0) {

        NSLog(@"FT_FUNCTION_NUM_OPEN_CARD success!");

        [self startDeviceHealthCheck];

        char newUid[128] = {0};

        HexToStr(newUid, cardHandle->uid, cardHandle->uidLen);

        if(isOpen == NO) {

            isOpen = YES ;

            [self connected:1];

        }



        NSLog(@"FT_FUNCTION_NUM_OPEN_CARD Found tag UID: %s", newUid);



        // send tag read update to Cordova

        if (didFindTagWithUidCallbackId) {

            NSString *str = [NSString stringWithFormat:@"%s", newUid];

            NSArray* result = @[str];

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsMultipart:result];

            [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];

            [self.commandDelegate sendPluginResult:pluginResult callbackId:didFindTagWithUidCallbackId];

        }

    }

    else{

        NSLog(@"FT_FUNCTION_NUM_OPEN_CARD failed!");

    }



    if(isPolling == NO) {

        if(cardHandle != 0) {

            dispatch_async(dispatch_get_main_queue(), ^(void){

                // Dispose of any resources that can be recreated.

                [_ar530 NFC_Card_Close:cardHandle delegate:self];

            });

        }

    }

    else {

        [self poll];

    }

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



    [self stopDeviceHealthCheck];



    //release

    if (isOpen == NO) {

        return ;

    }



    isOpen = NO ;

    [self connected:0];

}



- (void)FTaR530GetInfoDidComplete:(unsigned char *)retData retDataLen:(unsigned int)retDataLen functionNum:(unsigned int)functionNum errCode:(unsigned int)errCode

{

    NSLog(@"FTaR530GetInfoDidComplete") ;



    NSString *retString = [NSString stringWithUTF8String:(char*)retData];



    //disconnected

    if (retString.length <= 0) {

        if(isOpen == YES) {

            [self stopDeviceHealthCheck];

        }

    } //connected

    else {

        [self startDeviceHealthCheck];

    }



    switch (functionNum) {

        case FT_FUNCTION_NUM_GET_DEVICEID:{

            NSLog(@"FT_FUNCTION_NUM_GET_DEVICEID") ;

            dispatch_async(dispatch_get_main_queue(), ^(void){



                if (retString.length <= 0) {

                    if(isOpen == YES) {

                        isOpen = NO ;

                        [self connected:0];

                    }

                }

                else {

                    if(isOpen == NO) {

                        isOpen = YES ;

                        [self connected:1];

                    }

                    [self poll];

                }



            });

            break;

        }

        default:

            break;

    }

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