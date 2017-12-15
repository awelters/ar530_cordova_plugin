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

     // Ar530 reader attributes
    FTaR530 *_ar530;
    NSTimer *_timer;

}


// Cordova functions
- (void)init:(CDVInvokedUrlCommand*)command;
- (void)setConfiguration:(CDVInvokedUrlCommand*)command;
- (void)setTagDiscoveredCallback:(CDVInvokedUrlCommand*)command;

// Internal functions
-(void)clearTimer;
-(void)poll;
-(void)openCard;
-(void)getOpenResult:(nfc_card_t)cardHandle;

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
