//
//  DLPRRenderer.m
//  DLPDFRenderer
//
//  Created by Vincent Esche on 12/4/13.
//  Copyright (c) 2013 Vincent Esche. All rights reserved.
//

#import "DLPRRenderer.h"

@interface DLPRRenderer () <UIWebViewDelegate>

@property (readwrite, weak, nonatomic) id<DLPRRendererDataSource> dataSource;
@property (readwrite, weak, nonatomic) id<DLPRRendererDelegate> delegate;

@property (readwrite, assign, nonatomic) NSUInteger currentPageIndex;
@property (readwrite, strong, nonatomic) id<DLPRPage> currentPage;

@property (readwrite, strong, nonatomic) NSMutableData *data;
@property (readwrite, strong, nonatomic) NSString *file;
@property (readwrite, strong, nonatomic) UIWebView *webview;
@property (readwrite, assign, nonatomic, getter = isBusy) BOOL busy;

@end

@implementation DLPRRenderer

- (id)initWithDataSource:(id<DLPRRendererDataSource>)dataSource delegate:(id<DLPRRendererDelegate>)delegate {
	NSAssert(dataSource, @"Method argument 'dataSource' must not be nil.");
	NSAssert(delegate, @"Method argument 'delegate' must not be nil.");
	self = [super init];
	if (self) {
		self.dataSource = dataSource;
		self.delegate = delegate;
		self.webview = [[UIWebView alloc] init];
	}
	return self;
}

- (void)dealloc {
	[self.webview removeFromSuperview];
	self.webview.delegate = nil;
}

- (void)finishedLoadingPage {
	NSUInteger pageIndex = self.currentPageIndex;
	[self addLoadedPage];
	if ([self.delegate respondsToSelector:@selector(renderer:failedPageAtIndex:)]) {
		[self.delegate renderer:self finishedPageAtIndex:pageIndex];
	}
	if ([self.dataSource renderer:self hasReachedLastPageAtIndex:pageIndex]) {
		UIGraphicsEndPDFContext();
		[self.delegate renderer:self finishedWithData:self.data orFile:self.file];
		self.data = nil;
		self.file = nil;
	} else {
		[self loadNextPage];
	}
}

- (void)failedLoadingPageWithError:(NSError *)error {
	NSUInteger pageIndex = self.currentPageIndex;
	UIGraphicsEndPDFContext();
	if ([self.delegate respondsToSelector:@selector(renderer:failedPageAtIndex:)]) {
		[self.delegate renderer:self failedPageAtIndex:pageIndex];
	}
	[self.delegate renderer:self failedWithError:error];
}

- (void)loadNextPage {
	if ([self.delegate respondsToSelector:@selector(renderer:preparePageAtIndex:)]) {
		[self.delegate renderer:self preparePageAtIndex:self.currentPageIndex];
	}
	NSUInteger pageIndex = self.currentPageIndex;
	id<DLPRPage> page = [self.dataSource renderer:self pageAtIndex:pageIndex];
	self.currentPage = page;
	self.webview.delegate = self;
	
	[page loadInWebView:self.webview];
}

- (void)addLoadedPage {
	id<DLPRPage> page = self.currentPage;
	
	CGSize paperSize = page.paperSize;
	DLPRPageMargins margins = page.margins;
	
	if (!paperSize.width) {
		paperSize.width = margins.left + margins.right;
		paperSize.width += [[self.webview stringByEvaluatingJavaScriptFromString:@"document.width"] doubleValue];
	}
	
	if (!paperSize.height) {
		paperSize.height = margins.top + margins.bottom;
		paperSize.height += [[self.webview stringByEvaluatingJavaScriptFromString:@"document.height"] doubleValue];
	}
	
	CGRect paperRect = CGRectMake(0.0, 0.0, paperSize.width, paperSize.height);
	CGRect printableRect = CGRectMake(margins.left, margins.top, paperSize.width - margins.left - margins.right, paperSize.height - margins.top - margins.bottom);

	UIGraphicsBeginPDFPageWithInfo(paperRect, [page boxInfoAsDictionary]);
	CGRect bounds = UIGraphicsGetPDFContextBounds();
	UIPrintPageRenderer *renderer = [[UIPrintPageRenderer alloc] init];
	
	[renderer setValue:[NSValue valueWithCGRect:paperRect] forKey:@"paperRect"];
	[renderer setValue:[NSValue valueWithCGRect:printableRect] forKey:@"printableRect"];
	
	[renderer prepareForDrawingPages:NSMakeRange(0, 1)];
	[renderer addPrintFormatter:self.webview.viewPrintFormatter startingAtPageAtIndex:0];
	[renderer drawPageAtIndex:0 inRect:bounds];
	self.currentPageIndex++;
	self.currentPage = nil;
}

- (void)renderToDataWithDocumentInfo:(DLPRDocumentInfo *)documentInfo {
	self.data = [NSMutableData data];
	self.currentPageIndex = 0;
	self.currentPage = nil;
	UIGraphicsBeginPDFContextToData(self.data, CGRectZero, [documentInfo asDictionary]);
	dispatch_async(dispatch_get_main_queue(), ^{
		[self loadNextPage];
	});
}

- (void)renderToFile:(NSString *)file withDocumentInfo:(DLPRDocumentInfo *)documentInfo {
	NSAssert(file, @"Method argument 'file' must not be nil.");
	self.file = file;
	self.currentPageIndex = 0;
	self.currentPage = nil;
	BOOL success = UIGraphicsBeginPDFContextToFile(self.file, CGRectZero, [documentInfo asDictionary]);
	if (success) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self loadNextPage];
		});
	} else {
		NSError *error = [NSError errorWithDomain:NSStringFromClass([self class]) code:1 userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Could not create PDF at path '%@'.", file]}];
		[self.delegate renderer:self failedWithError:error];
	}
}

#pragma mark - UIWebViewDelegate Protocol

- (void)webViewDidFinishLoad:(UIWebView *)webview {
	self.webview.delegate = nil;
	[self finishedLoadingPage];
}

- (void)webView:(UIWebView *)webview didFailLoadWithError:(NSError *)error {
	self.webview.delegate = nil;
	[self failedLoadingPageWithError:error];
}

@end
