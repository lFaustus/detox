//
//  WebSocket.m
//  Detox
//
//  Created by Tal Kol on 6/16/16.
//  Copyright © 2016 Wix. All rights reserved.
//

#import "WebSocket.h"
@import SocketRocket;

//Legacy API for apps that use old SocketRocket.
@interface SRWebSocket ()

- (void)send:(id)data;
- (BOOL)sendString:(NSString *)string error:(NSError **)error NS_SWIFT_NAME(send(string:));

@end


DTX_CREATE_LOG(WebSocket);

@interface WebSocket() <SRWebSocketDelegate>
{
	BOOL _isModern;
}

@property (nonatomic, retain) NSString *sessionId;
@property (nonatomic, retain) SRWebSocket *websocket;

@end


@implementation WebSocket

- (void)connectToServer:(NSString*)url withSessionId:(NSString*)sessionId
{
	if (self.websocket)
	{
		[self.websocket close];
		self.websocket = nil;
	}
	self.sessionId = sessionId;
	self.websocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:url]];
	self.websocket.delegate = self;
	[self.websocket open];
	
	_isModern = [self.websocket respondsToSelector:@selector(sendString:error:)];
}

- (void)sendAction:(NSString*)type withParams:(NSDictionary*)params withMessageId:(NSNumber*)messageId
{
	NSDictionary *data = @{@"type": type, @"params": params, @"messageId": messageId};
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:kNilOptions error:&error];
	if (jsonData == nil)
	{
		dtx_log_error(@"Error decoding sendAction encode - %@", error);
		return;
	}
	dtx_log_info(@"Action Sent: %@", type);
	NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	
	if(_isModern)
	{
		[self.websocket sendString:json error:NULL];
	}
	else
	{
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
		[self.websocket send:json];
#pragma GCC diagnostic pop
	}
}

- (void)receiveAction:(NSString*)json
{
	NSError *error;
	NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
	NSDictionary *data = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];
	if (data == nil)
	{
		dtx_log_error(@"Error decoding receiveAction decode - %@", error);
		return;
	}
	NSString *type = [data objectForKey:@"type"];
	if (type == nil)
	{
		dtx_log_error(@"receiveAction missing type");
		return;
	}
	NSDictionary *params = [data objectForKey:@"params"];
	if (params != nil && ![params isKindOfClass:[NSDictionary class]])
	{
		dtx_log_error(@"receiveAction invalid params");
		return;
	}
	NSNumber *messageId = [data objectForKey:@"messageId"];
	if (messageId != nil && ![messageId isKindOfClass:[NSNumber class]])
	{
		dtx_log_error(@"receiveAction invalid messageId");
		return;
	}
	dtx_log_info(@"Action Received: %@", type);
	if (self.delegate) [self.delegate websocketDidReceiveAction:type withParams:params withMessageId:messageId];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
	[self sendAction:@"login" withParams:@{@"sessionId": self.sessionId, @"role": @"testee"} withMessageId:@0];
	if (self.delegate) [self.delegate websocketDidConnect];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessageWithString:(NSString *)string
{
	[self receiveAction:string];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
	dtx_log_error(@"Socket failed with error: %@", error);
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
	dtx_log_info(@"Socket closed: %@", reason);
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
	if(_isModern == YES)
	{
		return;
	}
	
	if([message isKindOfClass:[NSString class]])
	{
		[self receiveAction:message];
	}
}


@end
