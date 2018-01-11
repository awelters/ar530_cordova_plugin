/*

 Ar530Plugin.m

 Uses Ar530 SDK

 */



#import "Ar530Plugin.h"



BOOL isOpen = NO ;

BOOL isPolling = NO ;

int defaultScanPeriod = 1000;

int scanPeriod = -1;

int connnectedState = -1;

@implementation Ar530Plugin



/** Initialise the plugin */

- (void)init:(CDVInvokedUrlCommand*)command {

    if (!_ar530) {
        NSLog(@"R init") ;
        
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

        //reset device info
        [self resetDeviceInfo];

        //configure
        [self configure:command];

        //kick off
        [self kickoff];

    }

}

- (void)configure:(CDVInvokedUrlCommand*)command {
    NSLog(@"R configure") ;

    NSString* shouldPollString = [command.arguments objectAtIndex:0];
    NSString* periodString = [command.arguments objectAtIndex:1];
    int shouldPoll = [shouldPollString intValue];
    BOOL startPoll = NO;

    [self clearScanningTimer];

    //need to auto poll if configuring to poll, has already initialized the plugin, and is not polling now already auto polling
    if (shouldPoll == 1 && scanPeriod != -1 && isPolling == NO) {
        startPoll = YES;
    }

    isPolling = NO;

    if (shouldPoll == 0) {

        int period = [periodString intValue];

        if (period == 0 || period >= defaultScanPeriod) {

            scanPeriod = period;

        } else {

            scanPeriod = defaultScanPeriod;

            NSString *str = [NSString stringWithFormat:@"Scan period either must be turned off aka 0 or it must be >= %d", defaultScanPeriod];
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:str];

            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }

    } else {

        isPolling = YES;
        scanPeriod = 0;

        if( startPoll == YES ) {
            [self poll];
        }

    }
}

- (void)playSound:(CDVInvokedUrlCommand*)command {
    //[ _ar530 playSound:self];
}

- (void)disableSound:(CDVInvokedUrlCommand*)command {
    //[ _ar530 disabbleConnectSound:self];
}

- (void)getDeviceInfo:(CDVInvokedUrlCommand*)command {
    //dispatch_async(dispatch_get_main_queue(), ^{
        NSArray* result = @[_libVersion,_deviceID,_firmwareVersion,_deviceUID];
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsMultipart:result];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    //});
}

- (void)scanForTag:(CDVInvokedUrlCommand*)command {

    if(isOpen == YES) {

        if (scanPeriod > 0) {
            [self startScanning];
        }

        if(isPolling == NO) {
            isPolling = YES;

            [self poll];
        }

    }

}

- (void)stopScanForTag:(CDVInvokedUrlCommand*)command {

    if (scanPeriod > 0) {
        [self stopScanning];
    }
    else {
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


-(void)kickoff

{

    dispatch_async(dispatch_get_main_queue(), ^(void){

        // Here we need waiting until the device has initialized

        [NSThread sleepForTimeInterval:2.5f] ;

        [ _ar530 getDeviceID:self];

    });

}

-(void)resetDeviceInfo

{
    NSLog(@"R resetDeviceInfo") ;

    _libVersion = [NSString stringWithFormat:@""];
    _deviceID = [NSString stringWithFormat:@""];
    _firmwareVersion = [NSString stringWithFormat:@""];
    _deviceUID = [NSString stringWithFormat:@""];
}

-(void)startScanning {

    if (scanPeriod > 0) {

        [self clearScanningTimer];

        NSLog(@"startScanning");

        double scanPeriodInSecs = scanPeriod / 1000.0;

        _timer = [NSTimer scheduledTimerWithTimeInterval: scanPeriodInSecs

                                                  target: self

                                                selector: @selector(stopScanning)

                                                userInfo: nil

                                                 repeats: NO];

    }

}

-(void)clearScanningTimer {

    NSLog(@"clearScanningTimer");

    if ([_timer isValid]) {

        [_timer invalidate];

    }

    _timer=nil;
}

-(void)stopScanning {

    NSLog(@"stopScanning");

    [self clearScanningTimer];

    if (scanPeriod > 0) {
        isPolling = NO;
    }
}



-(void)poll {

    if( isOpen == YES && isPolling == YES ) {

        dispatch_async(dispatch_get_main_queue(), ^(void){

            [_ar530 NFC_Card_Open:self];

        });

    }

}



-(void)connected:(int)yesOrNo

{

    NSLog(@"yesOrNo: %d", yesOrNo);

    //don't report an unknown connection if we know we are disconnected
    if(connnectedState == 0 && yesOrNo == -1) {
        return;
    }

    if(yesOrNo == -1) {
        connnectedState = 0;
    }
    else {
        connnectedState = yesOrNo;
    }

    NSLog(@"connected: %d", connnectedState);

    // send tag read update to Cordova

    if (deviceConnectedCallbackId) {

        NSString *str = [NSString stringWithFormat:@"%d", connnectedState];

        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:str];

        [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];

        [self.commandDelegate sendPluginResult:pluginResult callbackId:deviceConnectedCallbackId];

    }

}




-(void)getOpenResult:(nfc_card_t)cardHandle

{

    if(cardHandle != 0) {

        NSLog(@"FT_FUNCTION_NUM_OPEN_CARD success!");

        char newUid[128] = {0};

        HexToStr(newUid, cardHandle->uid, cardHandle->uidLen);

        if(isOpen == NO) {

            isOpen = YES ;

            [self connected:1];

        }

        [self stopScanning];



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


    //if not in continous poll mode and the polling period is over
    if(isPolling == NO) {

        //and there is a card handle then dispose of resources
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



    [self kickoff];

}



- (void)FTaR530DidDisconnected{

    NSLog(@"R disconnect") ;



    [self stopScanning];
    [self resetDeviceInfo];


    //release

    if (isOpen == NO) {

        return ;

    }



    isOpen = NO ;

    [self connected:0];

}



- (void)FTaR530GetInfoDidComplete:(unsigned char *)retData retDataLen:(unsigned int)retDataLen functionNum:(unsigned int)functionNum errCode:(unsigned int)errCode

{

    NSLog(@"FTaR530GetInfoDidComplete %d",functionNum) ;

    NSString *retString = [NSString stringWithUTF8String:(char*)retData];

    switch (functionNum) {

        case FT_FUNCTION_NUM_GET_DEVICEID:{

            NSLog(@"FT_FUNCTION_NUM_GET_DEVICEID") ;

            if (retString.length <= 0) {

                //disconnected

                if(isOpen == YES) {

                    [self stopScanning];

                }

            } 

            else {

                //connected

            }

            dispatch_async(dispatch_get_main_queue(), ^(void){


                if (retString.length <= 0) {

                    if(isOpen == YES) {

                        isOpen = NO ;

                        [self connected:0];

                    }
                    else {

                        [self connected:-1];

                    }

                }

                else {

                    _libVersion = [NSString stringWithFormat:@"%@", [_ar530 getLibVersion], nil];
                    _deviceID = [NSString stringWithFormat:@"%@",retString,nil];
                    [_ar530 getFirmwareVersion:self];

                }



            });

            break;

        }

        case FT_FUNCTION_NUM_GET_FIRMWAREVERSION:{

            NSLog(@"FT_FUNCTION_NUM_GET_FIRMWAREVERSION") ;

            dispatch_async(dispatch_get_main_queue(), ^(void){
                
                _firmwareVersion = [NSString stringWithFormat:@"%@",retString,nil];
                
                // get device UID
                [ _ar530 getDeviceUID:self];
                
                //isOpen = YES ;
                
            });
            break;
        }

        case FT_FUNCTION_NUM_GET_DEVICEUID:{

            NSLog(@"FT_FUNCTION_NUM_GET_DEVICEUID") ;
            
            dispatch_async(dispatch_get_main_queue(), ^(void){
                
                _deviceUID = [NSString stringWithFormat:@"%@",retString,nil];

                if(isOpen == NO) {

                    isOpen = YES ;

                    [self connected:1];

                }
                
                [self poll];

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



@end
