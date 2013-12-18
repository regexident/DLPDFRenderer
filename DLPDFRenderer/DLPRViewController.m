//
//  DLPRViewController.m
//  DLPDFRenderer
//
//  Created by Vincent Esche on 12/4/13.
//  Copyright (c) 2013 Vincent Esche. All rights reserved.
//

#import "DLPRViewController.h"

#import "DLPRRenderer.h"
#import "DLPRURLProtocol.h"

@interface DLPRViewController () <DLPRRendererDataSource, DLPRRendererDelegate>

@property (readwrite, strong, nonatomic) DLPRRenderer *renderer;
@property (readwrite, assign, nonatomic) NSUInteger pageCount;
@property (readwrite, strong, nonatomic) UIWebView *webview;
@property (readwrite, strong, nonatomic) UIProgressView *progressView;

@end

@implementation DLPRViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.pageCount = 10;
	self.renderer = [[DLPRRenderer alloc] initWithDataSource:self delegate:self];
	
	[NSURLProtocol registerClass:[DLPRURLProtocol class]];
}

- (void)viewWillAppear:(BOOL)animated {
	self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
	NSLog(@"self.progressView.frame: %@", NSStringFromCGRect(self.progressView.frame));
	CGRect bounds = self.view.bounds;
	self.progressView.center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	
	self.webview = [[UIWebView alloc] initWithFrame:self.view.bounds];
	[self.view addSubview:self.webview];
		
	[self.view addSubview:self.progressView];
	
	NSString *directory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
	NSString *filePath = [directory stringByAppendingPathComponent:@"test.pdf"];
	[self.renderer renderToFile:filePath withDocumentInfo:nil];
	
//	[self.renderer renderToDataWithDocumentInfo:nil];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - DLPRRendererDataSource Protocol

- (BOOL)renderer:(DLPRRenderer *)renderer hasReachedLastPageAtIndex:(NSUInteger)pageIndex {
	return (pageIndex + 1 == self.pageCount);
}

- (id<DLPRPage>)renderer:(DLPRRenderer *)renderer pageAtIndex:(NSUInteger)pageIndex {
	UIColor *color = [UIColor colorWithHue:(1.0 / self.pageCount) * pageIndex saturation:0.25 brightness:1.0 alpha:1.0];
	CGFloat rgba[4];
	[color getRed:(rgba + 0) green:(rgba + 1) blue:(rgba + 2) alpha:(rgba + 3)];
	NSString *hexColor = [NSString stringWithFormat:@"#%02X%02X%02X", (unsigned char)(rgba[0] * 255), (unsigned char)(rgba[1] * 255), (unsigned char)(rgba[2] * 255)];

	// Poor man's templating ahead.
	// You'd obviously want to use a proper templating library.
	NSError *error = nil;
	NSString *filePath = [[NSBundle mainBundle] pathForResource:@"template" ofType:@"html"];
	NSMutableString *source = [[NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error] mutableCopy];
	[source replaceOccurrencesOfString:@"{{color}}"
							withString:hexColor
							   options:0
								 range:NSMakeRange(0, source.length)];
	[source replaceOccurrencesOfString:@"{{page_number}}"
							withString:[NSString stringWithFormat:@"%lu", (unsigned long)pageIndex + 1]
							   options:0
								 range:NSMakeRange(0, source.length)];
	
	id<DLPRPage> page = nil;
	if (pageIndex == 0) {
		// setting a page's height to 0.0 causes the renderer to deduce the
		// paper height from the webview's content given a width of 1000.0:
		CGSize paperSize = CGSizeMake(1000.0, 0.0);
		page = [[DLPRURLPage alloc] initWithURL:[NSURL URLWithString:@"http://apple.com/"] paperSize:paperSize];
	} else {
		DLPRPageOrientation orientation = (pageIndex % 2) ? DLPRPageOrientationLandscape : DLPRPageOrientationPortrait;
		CGSize paperSize = [DLPRAbstractPage paperSizeForISO216A:4 forOrientation:orientation];
		page = [[DLPRSourcePage alloc] initWithSource:source paperSize:paperSize];
	}
	
	CGFloat insetInInches = 0.25;
	CGFloat insetInPixels = insetInInches * [DLPRAbstractPage resolution];
	page.margins = DLPRPageMarginsMakeUniform(insetInPixels);
	
	return page;
}

- (NSURL *)renderer:(DLPRRenderer *)renderer baseURLOfPageAtIndex:(NSUInteger)pageIndex {
	return [[NSBundle mainBundle] resourceURL];
}

#pragma mark - DLPRRendererDelegate Protocol

- (void)renderer:(DLPRRenderer *)renderer finishedWithData:(NSData *)data orFile:(NSString *)file {
	NSLog(@"%s", __FUNCTION__);
	[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
	if (data) {
		[self.webview loadData:data MIMEType:@"application/pdf" textEncodingName:@"utf-8" baseURL:nil];
	} else if (file) {
		[self.webview loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:file]]];
	}
	[self.progressView removeFromSuperview];
}

- (void)renderer:(DLPRRenderer *)renderer failedWithError:(NSError *)error {
	NSLog(@"%s", __FUNCTION__);
	NSLog(@"Error: %@", error);
	[self.progressView removeFromSuperview];
}

- (void)renderer:(DLPRRenderer *)renderer finishedPageAtIndex:(NSUInteger)index {
	NSLog(@"%s", __FUNCTION__);
	self.progressView.progress = (CGFloat)(index + 1) / self.pageCount;
}

- (void)renderer:(DLPRRenderer *)renderer failedPageAtIndex:(NSUInteger)index {
	NSLog(@"%s", __FUNCTION__);
}

@end
