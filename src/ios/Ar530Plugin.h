/*

 Ar530Plugin.h

 Uses Ar530 SDK

 */



#import "FTaR530.h"

#import "utils.h"

#import <Cordova/CDV.h>



@interface Ar530Plugin : CDVPlugin <FTaR530Delegate>

{



    // Cordova attributes

    NSString* didFindTagWithUidCallbackId;

    NSString* deviceConnectedCallbackId;


     // Ar530 reader attributes

    FTaR530 *_ar530;

    NSString* _libVersion;

    NSString* _deviceID;

    NSString* _firmwareVersion;

    NSString* _deviceUID;


    // internal attributes

    NSTimer *_timer;



}





// Cordova functions

- (void)init:(CDVInvokedUrlCommand*)command;

- (void)configure:(CDVInvokedUrlCommand*)command;

- (void)playSound:(CDVInvokedUrlCommand*)command;

- (void)disableSound:(CDVInvokedUrlCommand*)command;

- (void)getDeviceInfo:(CDVInvokedUrlCommand*)command;

- (void)scanForTag:(CDVInvokedUrlCommand*)command;

- (void)stopScanForTag:(CDVInvokedUrlCommand*)command;

- (void)setDeviceConnectedCallback:(CDVInvokedUrlCommand*)command;

- (void)setTagDiscoveredCallback:(CDVInvokedUrlCommand*)command;



// Internal functions

-(void)kickoff;

-(void)resetDeviceInfo;

-(void)startScanning;

-(void)clearScanningTimer;

-(void)stopScanning;

-(void)poll;

-(void)connected:(int)yesOrNo;

-(void)cardIsOpen:(nfc_card_t)cardHandle;

-(void)closeOpenCard:(nfc_card_t)cardHandle;

-(void)getOpenResult:(nfc_card_t)cardHandle;

-(void)getRecognizeResult:(nfc_card_t)cardHandle errCode:(unsigned int)errCode;

-(void)tagDiscovered;

-(void)readMifareUltralightMemory:(nfc_card_t)cardHandle;

-(void)parseTransmitResult:(nfc_card_t)cardHandle result:(NSString *)result;

-(void)transmit:(nfc_card_t)cardHandle apduText:(NSString *)apduText;

-(void)getTransmitResult:(nfc_card_t)cardHandle retData:(unsigned char *)retData retDataLen:(unsigned int)retDataLen errCode:(unsigned int)errCode;


// SDK reader delegates

- (void)FTaR530DidConnected;

- (void)FTaR530DidDisconnected;



/*@Name:        -(void)FTNFCDidComplete:(nfc_card_t)cardHandle retData:(unsigned char *)retData retDataLen:(unsigned int)retDataLen functionNum:(unsigned int)funcNum errCode:(unsigned int)errCode;

 *@Function:    This function will be callback when NFC function completed.

 *@Parameter:   OUT:(1).(nfc_card_t)cardHandle:     the card's handle

 *                  (2).(unsigned char *)retData:   return data

 *                  (3).(unsigned int)retDataLen:   return data length

 *                  (4).(unsigned int)funcNum:      The function number

 *                  (5).unsigned int)errCode:       The error code(0-success, other value-error code)

 */

-(void)FTNFCDidComplete:(nfc_card_t)cardHandle retData:(unsigned char *)retData retDataLen:(unsigned int)retDataLen functionNum:(unsigned int)funcNum errCode:(unsigned int)errCode;





/*@Name:        -(void)FTaR530GetInfoDIdComplete:(unsigned char *)retData retDataLen:(unsigned int)retDataLen  functionNum:(unsigned int)functionNum errCode:(unsigned int)errCode;

 *@Function:    This function will be callback when Get Firmware Version or Get Device ID function completed.

 *@Parameter:   OUT:(1).(unsigned char *)retData:   return Data

 *                  (2).(unsigned int)retDataLen:   return Data length

 *                  (3).(unsigned int)functionNum:  The function number

 *                  (4).(unsigned int)errCode:      The error code(0-sucess,other value-error code)

 *

 */

-(void)FTaR530GetInfoDidComplete:(unsigned char *)retData retDataLen:(unsigned int)retDataLen  functionNum:(unsigned int)functionNum errCode:(unsigned int)errCode;



@end
