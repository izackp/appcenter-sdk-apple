// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSAppCenterInternal.h"
#import "MSChannelGroupProtocol.h"
#import "MSChannelUnitConfiguration.h"
#import "MSChannelUnitProtocol.h"
#import "MSCrashHandlerSetupDelegate.h"
#import "MSCrashesInternal.h"
#import "MSCrashesTestUtil.h"
#import "MSCrashesUtil.h"
#import "MSErrorAttachmentLog.h"
#import "MSException.h"
#import "MSHandledErrorLog.h"
#import "MSLogWithProperties.h"
#import "MSTestFrameworks.h"
#import "MSWrapperCrashesHelper.h"

@interface MSWrapperCrashesHelperTests : XCTestCase
@end

static NSString *const kMSTestAppSecret = @"TestAppSecret";
static NSString *const kMSTypeHandledError = @"handledError";

@implementation MSWrapperCrashesHelperTests

- (void)testSettingAndGettingDelegateWorks {

  // If
  id<MSCrashHandlerSetupDelegate> delegateMock = OCMProtocolMock(@protocol(MSCrashHandlerSetupDelegate));
  [MSWrapperCrashesHelper setCrashHandlerSetupDelegate:delegateMock];

  // When
  id<MSCrashHandlerSetupDelegate> retrievedDelegate = [MSWrapperCrashesHelper getCrashHandlerSetupDelegate];

  // Then
  assertThat(delegateMock, equalTo(retrievedDelegate));
}

- (void)testTrackModelExceptionWitExceptionOnly {

  // If
  __block NSString *type;
  __block NSString *userId;
  __block NSString *errorId;
  __block MSException *exception;
  NSString *expectedUserId = @"alice";
  id<MSChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSChannelUnitProtocol));
  id<MSChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSChannelGroupProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"Crashes"];
                            }]])
      .andReturn(channelUnitMock);
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(OCMProtocolMock(@protocol(MSChannelUnitProtocol)));
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSLogWithProperties class]] flags:MSFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSHandledErrorLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        userId = log.userId;
        errorId = log.errorId;
        exception = log.exception;
      });
  [MSAppCenter configureWithAppSecret:kMSTestAppSecret];
  [MSAppCenter setUserId:expectedUserId];
  [[MSCrashes sharedInstance] startWithChannelGroup:channelGroupMock
                                          appSecret:kMSTestAppSecret
                            transmissionTargetToken:nil
                                    fromApplication:YES];

  // When
  MSException *expectedException = [MSException new];
  expectedException.message = @"Oh this is wrong...";
  expectedException.stackTrace = @"mock stacktrace";
  expectedException.type = @"Some.Exception";
  [MSWrapperCrashesHelper trackModelException:expectedException withProperties:nil withAttachments:nil];

  // Then
  assertThat(type, is(kMSTypeHandledError));
  assertThat(userId, is(expectedUserId));
  assertThat(errorId, notNilValue());
  assertThat(exception, is(expectedException));
}

- (void)testTrackModelExceptionWithExceptionAndProperties {

  // If
  __block NSString *type;
  __block NSString *userId;
  __block NSString *errorId;
  __block MSException *exception;
  __block NSDictionary<NSString *, NSString *> *properties;
  NSString *expectedUserId = @"alice";
  id<MSChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSChannelUnitProtocol));
  id<MSChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSChannelGroupProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"Crashes"];
                            }]])
      .andReturn(channelUnitMock);
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(OCMProtocolMock(@protocol(MSChannelUnitProtocol)));
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSAbstractLog class]] flags:MSFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSHandledErrorLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        userId = log.userId;
        errorId = log.errorId;
        exception = log.exception;
        properties = log.properties;
      });
  [MSAppCenter setUserId:expectedUserId];
  [MSAppCenter configureWithAppSecret:kMSTestAppSecret];
  [[MSCrashes sharedInstance] startWithChannelGroup:channelGroupMock
                                          appSecret:kMSTestAppSecret
                            transmissionTargetToken:nil
                                    fromApplication:YES];

  // When
  MSException *expectedException = [MSException new];
  expectedException.message = @"Oh this is wrong...";
  expectedException.stackTrace = @"mock stacktrace";
  expectedException.type = @"Some.Exception";
  NSDictionary *expectedProperties = @{@"milk" : @"yes", @"cookie" : @"of course"};
  [MSWrapperCrashesHelper trackModelException:expectedException withProperties:expectedProperties withAttachments:nil];

  // Then
  assertThat(type, is(kMSTypeHandledError));
  assertThat(userId, is(expectedUserId));
  assertThat(errorId, notNilValue());
  assertThat(exception, is(expectedException));
  assertThat(properties, is(expectedProperties));
}

- (void)testTrackModelExceptionWithExceptionAndAttachments {

  // If
  __block NSString *type;
  __block NSString *userId;
  __block NSString *errorId;
  __block MSException *exception;
  __block NSMutableArray<MSErrorAttachmentLog *> *errorAttachmentLogs = [NSMutableArray new];
  NSString *expectedUserId = @"alice";
  id<MSChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSChannelUnitProtocol));
  id<MSChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSChannelGroupProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"Crashes"];
                            }]])
      .andReturn(channelUnitMock);
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(OCMProtocolMock(@protocol(MSChannelUnitProtocol)));
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSHandledErrorLog class]] flags:MSFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSHandledErrorLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        userId = log.userId;
        errorId = log.errorId;
        exception = log.exception;
      });
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSErrorAttachmentLog class]] flags:MSFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSErrorAttachmentLog *log;
        [invocation getArgument:&log atIndex:2];
        [errorAttachmentLogs addObject:log];
      });
  [MSAppCenter configureWithAppSecret:kMSTestAppSecret];
  [MSAppCenter setUserId:expectedUserId];
  [[MSCrashes sharedInstance] startWithChannelGroup:channelGroupMock
                                          appSecret:kMSTestAppSecret
                            transmissionTargetToken:nil
                                    fromApplication:YES];
  NSData *expectedData = [@"<file><request>Please attach me</request><reason>I am a nice "
                          @"data.</reason></file>" dataUsingEncoding:NSUTF8StringEncoding];
  MSErrorAttachmentLog *errorAttachmentLog1 = [[MSErrorAttachmentLog alloc] initWithFilename:@"text.txt"
                                                                              attachmentText:@"Please attach me, I am a nice text."];
  MSErrorAttachmentLog *errorAttachmentLog2 = [[MSErrorAttachmentLog alloc] initWithFilename:@"binary.xml"
                                                                            attachmentBinary:expectedData
                                                                                 contentType:@"text/xml"];
  NSArray<MSErrorAttachmentLog *> *attachments = @[ errorAttachmentLog1, errorAttachmentLog2 ];

  // When
  MSException *expectedException = [MSException new];
  expectedException.message = @"Oh this is wrong...";
  expectedException.stackTrace = @"mock stacktrace";
  expectedException.type = @"Some.Exception";
  [MSWrapperCrashesHelper trackModelException:expectedException withProperties:nil withAttachments:attachments];

  // Then
  XCTAssertEqual(type, kMSTypeHandledError);
  XCTAssertEqual(userId, expectedUserId);
  XCTAssertNotNil(errorId, );
  XCTAssertEqualObjects(exception, expectedException);
  XCTAssertEqual([errorAttachmentLogs count], [attachments count]);
  XCTAssertEqualObjects(errorAttachmentLogs[0], errorAttachmentLog1);
  XCTAssertEqualObjects(errorAttachmentLogs[1], errorAttachmentLog2);
}

- (void)testTrackModelExceptionWithAllParameters {

  // If
  __block NSString *type;
  __block NSString *userId;
  __block NSString *errorId;
  __block MSException *exception;
  __block NSDictionary<NSString *, NSString *> *properties;
  __block NSMutableArray<MSErrorAttachmentLog *> *errorAttachmentLogs = [NSMutableArray new];
  NSString *expectedUserId = @"alice";
  id<MSChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSChannelUnitProtocol));
  id<MSChannelGroupProtocol> channelGroupMock = OCMProtocolMock(@protocol(MSChannelGroupProtocol));
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:[OCMArg checkWithBlock:^BOOL(MSChannelUnitConfiguration *configuration) {
                              return [configuration.groupId isEqualToString:@"Crashes"];
                            }]])
      .andReturn(channelUnitMock);
  OCMStub([channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(OCMProtocolMock(@protocol(MSChannelUnitProtocol)));
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSHandledErrorLog class]] flags:MSFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSHandledErrorLog *log;
        [invocation getArgument:&log atIndex:2];
        type = log.type;
        userId = log.userId;
        errorId = log.errorId;
        exception = log.exception;
        properties = log.properties;
      });
  OCMStub([channelUnitMock enqueueItem:[OCMArg isKindOfClass:[MSErrorAttachmentLog class]] flags:MSFlagsDefault])
      .andDo(^(NSInvocation *invocation) {
        MSErrorAttachmentLog *log;
        [invocation getArgument:&log atIndex:2];
        [errorAttachmentLogs addObject:log];
      });
  [MSAppCenter setUserId:expectedUserId];
  [MSAppCenter configureWithAppSecret:kMSTestAppSecret];
  [[MSCrashes sharedInstance] startWithChannelGroup:channelGroupMock
                                          appSecret:kMSTestAppSecret
                            transmissionTargetToken:nil
                                    fromApplication:YES];
  NSData *expectedData = [@"<file><request>Please attach me</request><reason>I am a nice "
                          @"data.</reason></file>" dataUsingEncoding:NSUTF8StringEncoding];
  MSErrorAttachmentLog *errorAttachmentLog1 = [[MSErrorAttachmentLog alloc] initWithFilename:@"text.txt"
                                                                              attachmentText:@"Please attach me, I am a nice text."];
  MSErrorAttachmentLog *errorAttachmentLog2 = [[MSErrorAttachmentLog alloc] initWithFilename:@"binary.xml"
                                                                            attachmentBinary:expectedData
                                                                                 contentType:@"text/xml"];
  NSArray<MSErrorAttachmentLog *> *attachments = @[ errorAttachmentLog1, errorAttachmentLog2 ];

  // When
  MSException *expectedException = [MSException new];
  expectedException.message = @"Oh this is wrong...";
  expectedException.stackTrace = @"mock stacktrace";
  expectedException.type = @"Some.Exception";
  NSDictionary *expectedProperties = @{@"milk" : @"yes", @"cookie" : @"of course"};
  [MSWrapperCrashesHelper trackModelException:expectedException withProperties:expectedProperties withAttachments:attachments];

  // Then
  XCTAssertEqual(type, kMSTypeHandledError);
  XCTAssertEqual(userId, expectedUserId);
  XCTAssertNotNil(errorId);
  XCTAssertEqualObjects(exception, expectedException);
  XCTAssertEqualObjects(properties, expectedProperties);
  XCTAssertEqual([errorAttachmentLogs count], [attachments count]);
  XCTAssertEqualObjects(errorAttachmentLogs[0], errorAttachmentLog1);
  XCTAssertEqualObjects(errorAttachmentLogs[1], errorAttachmentLog2);
}

@end
