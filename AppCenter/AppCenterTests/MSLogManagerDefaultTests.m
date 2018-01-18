#import "MSAbstractLogInternal.h"
#import "MSChannelConfiguration.h"
#import "MSChannelDefault.h"
#import "MSHttpSenderPrivate.h"
#import "MSLogManagerDefault.h"
#import "MSLogManagerDefaultPrivate.h"
#import "MSTestFrameworks.h"

@interface MSLogManagerDefaultTests : XCTestCase

@end

@implementation MSLogManagerDefaultTests

#pragma mark - Tests

- (void)testNewInstanceWasInitialisedCorrectly {

  // If
  id senderMock = OCMProtocolMock(@protocol(MSSender));
  id storageMock = OCMProtocolMock(@protocol(MSStorage));

  // When
  MSLogManagerDefault *sut = [[MSLogManagerDefault alloc] initWithSender:senderMock storage:storageMock];

  // Then
  assertThat(sut, notNilValue());
  assertThat(sut.logsDispatchQueue, notNilValue());
  assertThat(sut.channels, isEmpty());
  assertThat(sut.sender, equalTo(senderMock));
  assertThat(sut.storage, equalTo(storageMock));
}

- (void)testInitNewChannel {

  // If
  NSString *groupId = @"AppCenter";
  MSPriority priority = MSPriorityDefault;
  float flushInterval = 1.0;
  NSUInteger batchSizeLimit = 10;
  NSUInteger pendingBatchesLimit = 3;
  MSLogManagerDefault *sut = [[MSLogManagerDefault alloc] initWithSender:OCMProtocolMock(@protocol(MSSender))
                                                                 storage:OCMProtocolMock(@protocol(MSStorage))];

  // Then
  assertThat(sut.channels, isEmpty());

  // When
  [sut initChannelWithConfiguration:[[MSChannelConfiguration alloc] initWithGroupId:groupId
                                                                           priority:priority
                                                                      flushInterval:flushInterval
                                                                     batchSizeLimit:batchSizeLimit
                                                                pendingBatchesLimit:pendingBatchesLimit]];

  // Then
  MSChannelDefault *channel = sut.channels[groupId];
  assertThat(channel, notNilValue());
  XCTAssertTrue(channel.configuration.priority == priority);
  assertThatFloat(channel.configuration.flushInterval, equalToFloat(flushInterval));
  assertThatUnsignedLong(channel.configuration.batchSizeLimit, equalToUnsignedLong(batchSizeLimit));
  assertThatUnsignedLong(channel.configuration.pendingBatchesLimit, equalToUnsignedLong(pendingBatchesLimit));
}

- (void)testProcessingLogDoesNotEnqueueFilteredLogs {

  // If
  NSString *groupId = @"AppCenter";
  MSPriority priority = MSPriorityDefault;
  MSLogManagerDefault *sut = [[MSLogManagerDefault alloc] initWithSender:OCMProtocolMock(@protocol(MSSender))
                                                                 storage:OCMProtocolMock(@protocol(MSStorage))];
  [sut initChannelWithConfiguration:[[MSChannelConfiguration alloc] initWithGroupId:groupId
                                                                           priority:priority
                                                                      flushInterval:1.0
                                                                     batchSizeLimit:10
                                                                pendingBatchesLimit:3]];
  MSAbstractLog *log = [MSAbstractLog new];
  id<MSLogManagerDelegate> mockDelegate = OCMProtocolMock(@protocol(MSLogManagerDelegate));
  OCMStub([mockDelegate shouldFilterLog:log]).andReturn(YES);
  [sut addDelegate:mockDelegate];
  OCMReject([mockDelegate onEnqueuingLog:log withInternalId:OCMOCK_ANY]);

  // When
  [sut processLog:log forGroupId:groupId];

  // Then
  // onEnqueuingLog was not called, but onPreparedLog was called.
  OCMVerify([mockDelegate onPreparedLog:log withInternalId:OCMOCK_ANY]);

  // If
  // Add another filter that returns NO. The log should still be filtered because of mockDelegate.
  id<MSLogManagerDelegate> mockDelegate2 = OCMProtocolMock(@protocol(MSLogManagerDelegate));
  OCMStub([mockDelegate2 shouldFilterLog:log]).andReturn(NO);
  [sut addDelegate:mockDelegate2];
  OCMReject([mockDelegate2 onEnqueuingLog:log withInternalId:OCMOCK_ANY]);

  // When
  [sut processLog:log forGroupId:groupId];

  // Then
  // onEnqueuingLog was not called, but onPreparedLog was called.
  OCMVerify([mockDelegate2 onPreparedLog:log withInternalId:OCMOCK_ANY]);
}

- (void)testProcessingLogEnqueuesUnfilteredLogs {

  // If
  NSString *groupId = @"AppCenter";
  MSPriority priority = MSPriorityDefault;
  MSLogManagerDefault *sut = [[MSLogManagerDefault alloc] initWithSender:OCMProtocolMock(@protocol(MSSender))
                                                                 storage:OCMProtocolMock(@protocol(MSStorage))];
  [sut initChannelWithConfiguration:[[MSChannelConfiguration alloc] initWithGroupId:groupId
                                                                           priority:priority
                                                                      flushInterval:1.0
                                                                     batchSizeLimit:10
                                                                pendingBatchesLimit:3]];
  MSAbstractLog *log = [MSAbstractLog new];
  id<MSLogManagerDelegate> mockDelegate = OCMProtocolMock(@protocol(MSLogManagerDelegate));
  OCMStub([mockDelegate shouldFilterLog:log]).andReturn(NO);
  [sut addDelegate:mockDelegate];

  // When
  [sut processLog:log forGroupId:groupId];

  // Then
  OCMVerify([mockDelegate onPreparedLog:log withInternalId:OCMOCK_ANY]);
  OCMVerify([mockDelegate onEnqueuingLog:log withInternalId:OCMOCK_ANY]);
}

- (void)testProcessingLogWillTriggerOnProcessingCall {

  // If
  MSPriority priority = MSPriorityDefault;
  NSString *groupId = @"AppCenter";
  MSLogManagerDefault *sut = [[MSLogManagerDefault alloc] initWithSender:OCMProtocolMock(@protocol(MSSender))
                                                                 storage:OCMProtocolMock(@protocol(MSStorage))];
  id mockDelegate = OCMProtocolMock(@protocol(MSLogManagerDelegate));
  [sut addDelegate:mockDelegate];
  [sut initChannelWithConfiguration:[[MSChannelConfiguration alloc] initWithGroupId:groupId
                                                                           priority:priority
                                                                      flushInterval:1.0
                                                                     batchSizeLimit:10
                                                                pendingBatchesLimit:3]];

  MSAbstractLog *log = [MSAbstractLog new];

  // When
  [sut processLog:log forGroupId:groupId];

  // Then
  OCMVerify([mockDelegate onPreparedLog:log withInternalId:OCMOCK_ANY]);
  OCMVerify([mockDelegate onEnqueuingLog:log withInternalId:OCMOCK_ANY]);
}

- (void)testDelegatesConcurrentAccess {

  // If
  NSString *groupId = @"AppCenter";
  MSLogManagerDefault *sut = [[MSLogManagerDefault alloc] initWithSender:OCMProtocolMock(@protocol(MSSender))
                                                                 storage:OCMProtocolMock(@protocol(MSStorage))];
  MSAbstractLog *log = [MSAbstractLog new];
  for (int j = 0; j < 10; j++) {
    id mockDelegate = OCMProtocolMock(@protocol(MSLogManagerDelegate));
    [sut addDelegate:mockDelegate];
  }

  // When
  void (^block)() = ^{
    for (int i = 0; i < 10; i++) {
      [sut processLog:log forGroupId:groupId];
    }
    for (int i = 0; i < 100; i++) {
      [sut addDelegate:OCMProtocolMock(@protocol(MSLogManagerDelegate))];
    }
  };

  // Then
  XCTAssertNoThrow(block());
}

- (void)testResume {

  // If
  MSHttpSender *senderMock = OCMClassMock([MSHttpSender class]);
  id storageMock = OCMProtocolMock(@protocol(MSStorage));

  // When
  MSLogManagerDefault *sut = [[MSLogManagerDefault alloc] initWithSender:senderMock storage:storageMock];

  // When
  [sut resume];

  // Then
  OCMVerify([senderMock setEnabled:YES andDeleteDataOnDisabled:NO]);
}

- (void)testSuspend {

  // If
  MSHttpSender *senderMock = OCMClassMock([MSHttpSender class]);
  id storageMock = OCMProtocolMock(@protocol(MSStorage));

  // When
  MSLogManagerDefault *sut = [[MSLogManagerDefault alloc] initWithSender:senderMock storage:storageMock];

  // When
  [sut suspend];

  // Then
  OCMVerify([senderMock setEnabled:NO andDeleteDataOnDisabled:NO]);
}
@end
