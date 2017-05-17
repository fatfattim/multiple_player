#import "AVPlayerSwitchPlaybackViewController.h"
#import "AVPlayerDemoPlaybackView.h"
#import "AVPlayerDemoMetadataViewController.h"
#import "AVPlayerDemoPlaybackViewController.h"

static NSUInteger pager_count = 6;
static NSUInteger currentPage = 0;

@interface AVPlayerSwitchPlaybackViewController ()
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
- (id)init;
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (void)viewDidLoad;
- (void)setURL:(NSURL*)URL;
- (NSURL*)URL;

@property (nonatomic, strong) NSMutableArray *viewControllers;
@end

#pragma mark -
@implementation AVPlayerSwitchPlaybackViewController

#pragma mark Asset URL

- (void)setURL:(NSURL*)URL
{
	if (mURL != URL)
	{
		mURL = [URL copy];
	}
}

- (NSURL*)URL
{
	return mURL;
}

#pragma mark
#pragma mark View Controller

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
		
		[self setEdgesForExtendedLayout:UIRectEdgeAll];
	}
	
	return self;
}

- (id)init
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) 
    {
        return [self initWithNibName:@"AVPlayerDemoPlaybackView-iPad" bundle:nil];
	} 
    else 
    {
        return [self initWithNibName:@"AVPlayerSwitchPlaybackView" bundle:nil];
	}
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self viewDidLoadForPager];
    NSLog(@"viewDidAppear");
    [self loadScrollViewWithPage:0];
    [self loadScrollViewWithPage:1];
    [self scrollViewDidScroll:self.scrollView];
}


// ---------- Start of Pager ----------

- (void)viewDidLoadForPager
{
    
    NSUInteger numberPages = pager_count;
    
    // view controllers are created lazily
    // in the meantime, load the array with placeholders which will be replaced on demand
    NSMutableArray *controllers = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < numberPages; i++)
    {
        [controllers addObject:[NSNull null]];
    }
    self.viewControllers = controllers;
    
    // a page is the width of the scroll view
    self.scrollView.pagingEnabled = YES;
    
    //http://ztpala.com/2011/06/22/customize-page-size-uiscrollview/
    self.scrollView.clipsToBounds = NO;
    self.scrollView.bounces = NO;
    
    self.scrollView.contentSize = CGSizeMake(CGRectGetWidth(self.scrollView.frame) * numberPages, CGRectGetHeight(self.scrollView.frame));
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.scrollsToTop = NO;
    self.scrollView.delegate = self;
    
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    // remove all the subviews from our scrollview
    for (UIView *view in self.scrollView.subviews)
    {
        [view removeFromSuperview];
    }
    
    NSUInteger numPages = pager_count;
    
    // adjust the contentSize (larger or smaller) depending on the orientation
    self.scrollView.contentSize =
    CGSizeMake(CGRectGetWidth(self.scrollView.frame) * numPages, CGRectGetHeight(self.scrollView.frame));
    
    // clear out and reload our pages
    self.viewControllers = nil;
    NSMutableArray *controllers = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < numPages; i++)
    {
        [controllers addObject:[NSNull null]];
    }
    self.viewControllers = controllers;
    
    [self loadScrollViewWithPage:currentPage - 1];
    [self loadScrollViewWithPage:currentPage];
    [self loadScrollViewWithPage:currentPage + 1];
    [self gotoPage:NO]; // remain at the same page (don't animate)
}

- (void)loadScrollViewWithPage:(NSUInteger)page
{
    //NSLog(@"loadScrollViewWithPage: %lu" , (unsigned long)page);
    if (page >= pager_count)
        return;
    
    // replace the placeholder if necessary
    AVPlayerDemoPlaybackViewController *controller = [self.viewControllers objectAtIndex:page];
    if ((NSNull *)controller == [NSNull null])
    {
        controller = [[AVPlayerDemoPlaybackViewController alloc] init];
        [controller setURL:mURL];
        [self.viewControllers replaceObjectAtIndex:page withObject:controller];
    }
    
    // add the controller's view to the scroll view
    if (controller.view.superview == nil)
    {
        CGRect frame = self.scrollView.frame;
        
        CGFloat videoViewWidth = frame.size.width;
        frame.origin.x = (videoViewWidth) * page;
        frame.origin.y = -self.scrollView.frame.origin.y;
        frame.size.width = videoViewWidth;
        frame.size.height = frame.size.height;
        //frame.size.height = frame.size.height * 0.8;
        NSLog(@"y position : %f " , self.scrollView.frame.origin.y);
        controller.view.frame = frame;

        [self addChildViewController:controller];
        [self.scrollView addSubview:controller.view];
        [controller didMoveToParentViewController:self];
    }
    
    if(page % 2 == 1) { //testing codes
        controller.view.backgroundColor = [UIColor redColor];
    } else {
        controller.view.backgroundColor = [UIColor blueColor];
    }
}

// at the end of scroll animation, reset the boolean used when scrolls originate from the UIPageControl
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    // switch the indicator when more than 50% of the previous/next page is visible
    CGFloat pageWidth = CGRectGetWidth(self.scrollView.frame);
    NSUInteger page = floor((self.scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
    currentPage = page;
    
    // load the visible page and the page on either side of it (to avoid flashes when the user starts scrolling)
    
    [self loadScrollViewWithPage:page - 1];
    [self loadScrollViewWithPage:page];
    [self loadScrollViewWithPage:page + 1];
    // a possible optimization would be to unload the views+controllers which are no longer visible
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // Fix y position
    [scrollView setContentOffset: CGPointMake(scrollView.contentOffset.x, -scrollView.frame.origin.y)];
}

- (void)gotoPage:(BOOL)animated
{
    NSInteger page = currentPage;
    
    // load the visible page and the page on either side of it (to avoid flashes when the user starts scrolling)
    [self loadScrollViewWithPage:page - 1];
    [self loadScrollViewWithPage:page];
    [self loadScrollViewWithPage:page + 1];
    
    // update the scroll view to the appropriate page
    CGRect bounds = self.scrollView.bounds;
    bounds.origin.x = CGRectGetWidth(bounds) * page;
    bounds.origin.y = 0;
    [self.scrollView scrollRectToVisible:bounds animated:animated];
    
}

// ---------- End of Pager ----------
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

-(void)setViewDisplayName
{
    /* Set the view title to the last component of the asset URL. */
    self.title = [mURL lastPathComponent];
}

@end

