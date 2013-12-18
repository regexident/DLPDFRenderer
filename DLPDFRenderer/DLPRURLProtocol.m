//
//  DLPRURLProtocol.m
//  DLPDFRenderer
//
//  Created by Vincent Esche on 12/11/13.
//  Copyright (c) 2013 Vincent Esche. All rights reserved.
//

#import "DLPRURLProtocol.h"

@implementation DLPRURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
	if ([request.URL.scheme caseInsensitiveCompare:@"test"] == NSOrderedSame) {
		return YES;
	}
	return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
	return request;
}

- (void)startLoading {
	NSData *data = [self dataForRequest];
	if (!data) {
		NSError *error = nil;
		[self.client URLProtocol:self didFailWithError:error];
		return;
	}	
	NSURLResponse *response = [[NSURLResponse alloc] initWithURL:self.request.URL MIMEType:@"image/png" expectedContentLength:data.length textEncodingName:@"utf-8"];
	[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
	[self.client URLProtocol:self didLoadData:data];
	[self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {
	
}

- (NSData *)dataForRequest {
	UIImage *image = [UIImage imageNamed:@"trollface"];
	NSData *data = UIImagePNGRepresentation(image);
	return data;
}

@end
