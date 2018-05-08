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

char newUid[128] = {0};

unsigned int cardType = 0;

unsigned int memoryRead = 0;

NSString *memory = nil;

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

-(void)cardIsOpen:(nfc_card_t)cardHandle
{
    if(isOpen == NO) {

        isOpen = YES ;

        [self connected:1];

    }

    [self stopScanning];
}

-(void)closeOpenCard:(nfc_card_t)cardHandle
{
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

-(void)getOpenResult:(nfc_card_t)cardHandle
{
    if(cardHandle != 0) {
        NSLog(@"FT_FUNCTION_NUM_OPEN_CARD success!");

        memset(newUid, 0, sizeof newUid);

        HexToStr(newUid, cardHandle->uid, cardHandle->uidLen);

        [self cardIsOpen:cardHandle];

        NSLog(@"FT_FUNCTION_NUM_OPEN_CARD Found tag UID: %s", newUid);

        [_ar530 NFC_Card_Recognize:cardHandle delegate:self];
    }
    else{
        NSLog(@"FT_FUNCTION_NUM_OPEN_CARD failed!");
        [self closeOpenCard:cardHandle];
    }
    
}

-(void)getRecognizeResult:(nfc_card_t)cardHandle errCode:(unsigned int)errCode
{
    if(errCode == 0xFF) {
        NSLog(@"FT_FUNCTION_NUM_RECOGNIZE failed!");
        [self tagDiscovered:cardHandle];
        return;
    }
    
    unsigned int cardT = 0;
    NSString *tempkeyType = @"";

    char IDm[16 + 1] = {0};
    char PMm[16 + 1] = {0};
    char pupi[64] = {0};
//    char atqa[4+1] = {0} ;
    
    cardT = errCode;
    
    [self cardIsOpen:cardHandle];
    
    // get the card type
    if(cardHandle->type == CARD_TYPE_A) {
        tempkeyType = @"A" ;
        if(cardT == CARD_NXP_MIFARE_1K || cardT == CARD_NXP_MIFARE_4K){
            NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Card Type:Mifare 1K\nSAK:%02x", cardHandle->SAK);
        }else if(cardT == CARD_NXP_DESFIRE_EV1) {
            NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Card Type:A\nSAK:%02x", cardHandle->SAK);
        }else if(cardT == CARD_NXP_MIFARE_UL) {
            //this is the only one we can actually handle
            NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Card Type:Mifare 1K\nSAK:%02x", cardHandle->SAK);
        }else {
            NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Card Type:A\nSAK:%02x", cardHandle->SAK);
        }
    }
    else if(cardHandle->type == CARD_TYPE_B) {
        tempkeyType = @"B" ;
        if(cardT == CARD_NXP_M_1_B) {
            HexToStr(pupi, cardHandle->PUPI, cardHandle->PUPILen);
            NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Card Type:B\nATQB:%02x PUPI:%s", cardHandle->ATQB, pupi);
        }else if(cardT == CARD_NXP_TYPE_B) {
            HexToStr(pupi, cardHandle->PUPI, cardHandle->PUPILen);
            NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Card Type:B\nATQB:%02x PUPI:%s", cardHandle->ATQB, pupi);
        }
    }
    else if(cardHandle->type == CARD_TYPE_C) {                  // Felica
        HexToStr(IDm, cardHandle->IDm, 8);
        HexToStr(PMm, cardHandle->PMm, 8);
        NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Card Type:B\nFelica\nFelica_ID:%s\nPad_ID:%s", IDm, PMm);
    }
    else if(cardHandle->type == CARD_TYPE_D) {                  // Topaz
        HexToStr(pupi, cardHandle->PUPI, cardHandle->PUPILen);
        NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Card Type:Topaz\nATQA:%02x ID1z:%s", cardHandle->ATQA, pupi);
    }
    else{
        NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Unknown type of card!");
        [self closeOpenCard:cardHandle];
        return ;
    }
    
    cardType = cardHandle->type;

    memoryRead = 0;
    memory = @"";
    if(cardT == CARD_NXP_MIFARE_UL) {
        [self readMifareUltralightMemory:cardHandle];
    }
    else {
        [self tagDiscovered:cardHandle];
    }
}

-(void)tagDiscovered:(nfc_card_t)cardHandle {
    // send tag read update to Cordova
    
    if (didFindTagWithUidCallbackId) {
        
        NSString *str = [NSString stringWithFormat:@"%s", newUid];
        
        NSArray* result = @[str,memory];
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsMultipart:result];
        
        [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:didFindTagWithUidCallbackId];
    }
    
    [self closeOpenCard:cardHandle];
}

-(void)readMifareUltralightMemory:(nfc_card_t)cardHandle {
    dispatch_async(dispatch_get_main_queue(), ^(void){
        //FFB0000410
        //[self transmit:cardHandle apduText:@"FFCA000000"];
        //[self OnCusTransmit:cardHandle apduText:@"3B8F8001804F0CA0000003060300030000000068"];
        if(memoryRead == 0) {
            [self transmit:cardHandle apduText:@"FFB0000010"];
        }
        else if(memoryRead == 1) {
            [self transmit:cardHandle apduText:@"FFB0000410"];
        }
        else if(memoryRead == 2) {
            [self transmit:cardHandle apduText:@"FFB0000810"];
        }
        else if(memoryRead == 3) {
            [self transmit:cardHandle apduText:@"FFB0000C10"];
        }
    });
}

-(void)parseTransmitResult:(nfc_card_t)cardHandle result:(NSString *)result {
    //readMifareUltralightMemory result
    unsigned long len = [result length];
    if (len >= 5) {
        NSRange r;
        r.location = len-4;
        r.length = 4;
        NSString* readMemoryResult = [result substringWithRange:r];
        NSString* log = @"parseTransmitResult readMemoryResult:\n";
        log = [log stringByAppendingString:readMemoryResult];
        NSLog(log);
        if([readMemoryResult isEqualToString:@"9000"]) {
            r.location = 0;
            r.length = len-4;
            NSString* data = [result substringWithRange:r];
            NSString* logToo = @"parseTransmitResult data:\n";
            logToo = [logToo stringByAppendingString:data];
            NSLog(logToo);
            memory = [memory stringByAppendingString:data];
            if(++memoryRead < 4) {
                [self readMifareUltralightMemory:cardHandle];
            }
            else {
                NSString* logAlso = @"parseTransmitResult memory:\n";
                logAlso = [logAlso stringByAppendingString:memory];
                NSLog(logAlso);
                [self tagDiscovered:cardHandle];
            }
        }
        else {
            [self tagDiscovered:cardHandle];
        }
    } else {
        [self tagDiscovered:cardHandle];
    }
}

-(void)transmit:(nfc_card_t)cardHandle apduText:(NSString *)apduText {
    int nPos = 0;
    char apduStr[1024] = {0} ;
    char IDm[16 + 1] = {0};
    const char * ptmpStr = [apduText UTF8String];
    unsigned char apduBuf[100] = {0};
    unsigned int apduLen = 0;
    
    if(apduText == nil || [apduText isEqualToString:@""] ){
        NSLog(@"transmit APDU is error!") ;
        [self tagDiscovered:cardHandle];
        return;
    }
    
    if(cardType == CARD_TYPE_C){
        memcpy(apduStr + nPos, ptmpStr, 2) ;
        nPos += 2 ;
        
        HexToStr(IDm, cardHandle->IDm, 8);
        memcpy(apduStr + nPos, IDm, 16) ;
        nPos += 16 ;
        
        memcpy(apduStr + nPos, ptmpStr+2 , [apduText length] - 2) ;
        nPos += [apduText length] - 2 ;
        
        apduLen = nPos / 2;
        
    }
    else{
        memcpy(apduStr, ptmpStr, [apduText length]) ;
        apduLen = (unsigned int)[apduText length] / 2;
    }
    
    StrToHex(apduBuf, (char *)apduStr, (unsigned int)apduLen);
    
    NSLog(@"transmit send:\n%s", ptmpStr);
    //NFC_Card_No_Head_Transmit
    [_ar530 NFC_Card_Transmit:cardHandle sendBuf:apduBuf sendLen:apduLen delegate:self];
}

-(void)getTransmitResult:(nfc_card_t)cardHandle retData:(unsigned char *)retData retDataLen:(unsigned int)retDataLen errCode:(unsigned int)errCode
{
    if(0 == errCode) {
        char resultStr[1024] = {0};

        HexToStr(resultStr, retData, retDataLen);
        NSLog(@"FT_FUNCTION_NUM_TRANSMIT errCode = 0, recv:\n%s",resultStr);
        [self parseTransmitResult:cardHandle result:[NSString stringWithFormat:@"%s", resultStr]];
    }
    else if(NFC_CARD_ES_NO_SMARTCARD == errCode) {
        NSLog(@"FT_FUNCTION_NUM_TRANSMIT Not Found SmartCard! Please Reconnect with Reader!");
        [self tagDiscovered:cardHandle];
        return;
    }
    else if(retDataLen >= 2){
        char resultStr[1024] = {0};
        HexToStr(resultStr, retData, retDataLen);
        NSLog(@"FT_FUNCTION_NUM_TRANSMIT errCode != 0, recv:\n%s",resultStr);
        [self tagDiscovered:cardHandle];
    }
    else{
        NSLog(@"FT_FUNCTION_NUM_TRANSMIT NFC_transmit failed!");
        [self tagDiscovered:cardHandle];
        return;
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

        case FT_FUNCTION_NUM_RECOGNIZE:{
            NSLog(@"FT_FUNCTION_NUM_RECOGNIZE") ;
            [self getRecognizeResult:cardHandle errCode:errCode];
            break;
        }

        case FT_FUNCTION_NUM_TRANSMIT:{
            NSLog(@"FT_FUNCTION_NUM_TRANSMIT") ;
            [self getTransmitResult:cardHandle retData:retData retDataLen:retDataLen errCode:errCode];
            break ;
        }

        default:

            break;

    }

}



@end
