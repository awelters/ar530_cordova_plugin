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
            [self debug:@"About to scan for tags"];
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
            [self debug:@"About to scan for a tag"];
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


- (void)setDebugCallback:(CDVInvokedUrlCommand*)command {

    debugCallbackId = command.callbackId;

}


#pragma mark --Internal Methods--


-(void)debug:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^(void){
        NSString* logResult = [NSString stringWithFormat:@"------- DEBUG ---------: %@", msg];
        NSLog(logResult);
        if (debugCallbackId) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:msg];

            [pluginResult setKeepCallback:[NSNumber numberWithBool:YES]];

            [self.commandDelegate sendPluginResult:pluginResult callbackId:debugCallbackId];
        }
    });
}

-(void)kickoff

{

    dispatch_async(dispatch_get_main_queue(), ^(void){

        // Here we need waiting until the device has initialized

        [NSThread sleepForTimeInterval:2.5f] ;

        [self debug:@"Getting device id and library version"];

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
    NSString* debugInfo = [NSString stringWithFormat:@"connection state changed to: %d",connnectedState];
    [self debug:debugInfo];

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

                [self debug:@"Closing tag communication channel"];

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

        [self debug:@"Tag communication channel open, uid obtained, attempting to recognize card type"];

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
            [self debug:@"Tag Type: NXP_MIFARE_1K or NXP_MIFARE_4K"];
        }else if(cardT == CARD_NXP_DESFIRE_EV1) {
            NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Card Type:A\nSAK:%02x", cardHandle->SAK);
            [self debug:@"Tag Type: NXP_DESFIRE_EV1"];
        }else if(cardT == CARD_NXP_MIFARE_UL) {
            //this is the only one we can actually handle
            NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Card Type:Mifare 1K\nSAK:%02x", cardHandle->SAK);
            [self debug:@"Tag Type: NXP_MIFARE_UL"];
        }else {
            NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Card Type:A\nSAK:%02x", cardHandle->SAK);
            [self debug:@"Tag Type: A"];
        }
    }
    else if(cardHandle->type == CARD_TYPE_B) {
        tempkeyType = @"B" ;
        if(cardT == CARD_NXP_M_1_B) {
            HexToStr(pupi, cardHandle->PUPI, cardHandle->PUPILen);
            NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Card Type:B\nATQB:%02x PUPI:%s", cardHandle->ATQB, pupi);
            [self debug:@"Tag Type: NXP_M_1_B"];
        }else if(cardT == CARD_NXP_TYPE_B) {
            HexToStr(pupi, cardHandle->PUPI, cardHandle->PUPILen);
            NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Card Type:B\nATQB:%02x PUPI:%s", cardHandle->ATQB, pupi);
            [self debug:@"Tag Type: B"];
        }
    }
    else if(cardHandle->type == CARD_TYPE_C) {                  // Felica
        HexToStr(IDm, cardHandle->IDm, 8);
        HexToStr(PMm, cardHandle->PMm, 8);
        NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Card Type:B\nFelica\nFelica_ID:%s\nPad_ID:%s", IDm, PMm);
        [self debug:@"Tag Type: Felica"];
    }
    else if(cardHandle->type == CARD_TYPE_D) {                  // Topaz
        HexToStr(pupi, cardHandle->PUPI, cardHandle->PUPILen);
        NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Card Type:Topaz\nATQA:%02x ID1z:%s", cardHandle->ATQA, pupi);
        [self debug:@"Tag Type: Topaz"];
    }
    else{
        NSLog(@"FT_FUNCTION_NUM_RECOGNIZE Unknown type of card!");
        [self debug:@"Tag Type: Unknown"];
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
    NSString *str = [NSString stringWithFormat:@"%s", newUid];

    NSString* logResult = [NSString stringWithFormat:@"tagDiscovered, uid = %@, memory = %@", str, memory];
    NSLog(logResult);
    [self debug:logResult];

    // send tag read update to Cordova
    
    if (didFindTagWithUidCallbackId) {
        
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
            [self debug:@"Reading 16 bytes, pages 0-3"];
            [self transmit:cardHandle apduText:@"FFB0000010"];
        }
        else if(memoryRead == 1) {
            [self debug:@"Reading 16 bytes, pages 4-7"];
            [self transmit:cardHandle apduText:@"FFB0000410"];
        }
        else if(memoryRead == 2) {
            [self debug:@"Reading 16 bytes, pages 8-11"];
            [self transmit:cardHandle apduText:@"FFB0000810"];
        }
        else if(memoryRead == 3) {
            [self debug:@"Reading 16 bytes, pages 12-15"];
            [self transmit:cardHandle apduText:@"FFB0000C10"];
        }
    });
}

-(void)parseTransmitResult:(nfc_card_t)cardHandle result:(NSString *)result {
    NSString* logResult = [NSString stringWithFormat:@"parseTransmitResult result: %@", result];
    NSLog(logResult);
    [self debug:logResult];

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
    [self debug:@"About to transmit data to the tag"];
    //NFC_Card_No_Head_Transmit
    [_ar530 NFC_Card_Transmit:cardHandle sendBuf:apduBuf sendLen:apduLen delegate:self];
}

-(void)getTransmitResult:(nfc_card_t)cardHandle retData:(unsigned char *)retData retDataLen:(unsigned int)retDataLen errCode:(unsigned int)errCode
{
    NSString *debugInfo = nil;

    if(0 == errCode) {
        char resultStr[1024] = {0};

        HexToStr(resultStr, retData, retDataLen);
        NSLog(@"FT_FUNCTION_NUM_TRANSMIT errCode = 0, recv:\n%s",resultStr);
        [self parseTransmitResult:cardHandle result:[NSString stringWithFormat:@"%s", resultStr]];
    }
    else if(NFC_CARD_ES_NO_SMARTCARD == errCode) {
        NSLog(@"FT_FUNCTION_NUM_TRANSMIT Not Found SmartCard! Please Reconnect with Reader!");
        [self debug:@"Transmit error, tag not found"];
        [self tagDiscovered:cardHandle];
        return;
    }
    else if(retDataLen >= 2){
        char resultStr[1024] = {0};
        HexToStr(resultStr, retData, retDataLen);
        NSLog(@"FT_FUNCTION_NUM_TRANSMIT errCode != 0, recv:\n%s",resultStr);
        debugInfo = [NSString stringWithFormat:@"Transmit error, errCode = %d, resultStr = %s", errCode, resultStr];
        [self debug:debugInfo];
        [self tagDiscovered:cardHandle];
    }
    else{
        NSLog(@"FT_FUNCTION_NUM_TRANSMIT NFC_transmit failed!");
        debugInfo = [NSString stringWithFormat:@"Transmit error, errCode = %d", errCode];
        [self debug:debugInfo];
        [self tagDiscovered:cardHandle];
        return;
    }
}

#pragma mark - aR530 Delegates



- (void)FTaR530DidConnected{

    NSLog(@"R connected") ;

    [self debug:@"device connect event heard"];

    if(isOpen == YES){

        return ;

    }



    [self kickoff];

}



- (void)FTaR530DidDisconnected{

    NSLog(@"R disconnect") ;

    [self debug:@"device disconnect event heard"];

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

                    [self debug:@"Could not obtain device id and library version"];

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

                    NSString* logResult = [NSString stringWithFormat:@"Obtained device id (%@) and library version (%@), getting firmware version", _deviceID, _libVersion];
                    [self debug:logResult];

                    [_ar530 getFirmwareVersion:self];

                }



            });

            break;

        }

        case FT_FUNCTION_NUM_GET_FIRMWAREVERSION:{

            NSLog(@"FT_FUNCTION_NUM_GET_FIRMWAREVERSION") ;

            dispatch_async(dispatch_get_main_queue(), ^(void){
                
                _firmwareVersion = [NSString stringWithFormat:@"%@",retString,nil];

                NSString* logResult = [NSString stringWithFormat:@"Obtained firmware version (%@), getting device uid", _firmwareVersion];
                [self debug:logResult];

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

                NSString* logResult = [NSString stringWithFormat:@"Obtained device uid (%@)", _deviceUID];
                [self debug:logResult];

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
