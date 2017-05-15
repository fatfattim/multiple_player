#import "AVPlayerSwitchPlaybackViewController.h"
#import "AVPlayerDemoPlaybackView.h"
#import "AVPlayerDemoMetadataViewController.h"
#import "AVPlayerDemoPlaybackViewController.h"

static NSUInteger pager_count = 6;
static NSUInteger currentPage = 0;
@interface AVPlayerSwitchPlaybackViewController ()
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
- (id)init;
- (void)dealloc;
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (void)viewDidLoad;
- (void)handleSwipe:(UISwipeGestureRecognizer*)gestureRecognizer;
- (void)setURL:(NSURL*)URL;
- (NSURL*)URL;

@property (nonatomic, strong) NSMutableArray *viewControllers;
@end

@interface AVPlayerSwitchPlaybackViewController (Player)
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys;
@end

static void *AVPlayerSwitchPlaybackViewControllerRateObservationContext = &AVPlayerSwitchPlaybackViewControllerRateObservationContext;
static void *AVPlayerSwitchPlaybackViewControllerStatusObservationContext = &AVPlayerSwitchPlaybackViewControllerStatusObservationContext;
static void *AVPlayerSwitchPlaybackViewControllerCurrentItemObservationContext = &AVPlayerSwitchPlaybackViewControllerCurrentItemObservationContext;

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

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self viewDidLoadForPager];
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
    
    self.scrollView.contentSize = CGSizeMake(CGRectGetWidth(self.scrollView.frame) * numberPages, CGRectGetHeight(self.scrollView.frame));
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.scrollsToTop = NO;
    self.scrollView.delegate = self;
    
    
    // pages are created on demand
    // load the visible page
    // load the page on either side to avoid flashes when the user starts scrolling
    //
    [self loadScrollViewWithPage:0];
    [self loadScrollViewWithPage:1];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
       //NSLog(@"scrollViewWillBeginDragging: ");
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
    NSLog(@"loadScrollViewWithPage: %lu" , (unsigned long)page);
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
        
        NSLog(@"scroll height %f", frame.size.height);
        
        CGFloat videoViewWidth = frame.size.width;
        frame.origin.x = (videoViewWidth) * page;
        frame.origin.y = 0;
        frame.size.width = videoViewWidth;
        frame.size.height = frame.size.height * 0.5;
        
        controller.view.frame = frame;
        //controller.view.bounds = CGRectInset(controller.view.frame, 10.0f, 10.0f);
        controller.view.layoutMargins = UIEdgeInsetsMake(10, 10, 10, 10);

        [self addChildViewController:controller];
        [self.scrollView addSubview:controller.view];
        [controller didMoveToParentViewController:self];
    }
    
    if(page % 2 == 1) {
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

- (void)gotoPage:(BOOL)animated
{
    NSInteger page = currentPage;
    
    // load the visible page and the page on either side of it (to avoid flashes when the user starts scrolling)
    [self loadScrollViewWithPage:page - 1];
    [self loadScrollViewWithPage:page];
    [self loadScrollViewWithPage:page + 1];
    
    // update the scroll view to the appropriate page
    CGRect bounds = self.scrollView.bounds;
    NSLog(@"bounds %f" , bounds.size.width);
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

- (void)handleSwipe:(UISwipeGestureRecognizer *)gestureRecognizer
{
	UIView* view = [self view];
	UISwipeGestureRecognizerDirection direction = [gestureRecognizer direction];
	CGPoint location = [gestureRecognizer locationInView:view];
	
	if (location.y < CGRectGetMidY([view bounds]))
	{
		if (direction == UISwipeGestureRecognizerDirectionUp)
		{
			[UIView animateWithDuration:0.2f animations:
			^{
				[[self navigationController] setNavigationBarHidden:YES animated:YES];
			} completion:
			^(BOOL finished)
			{
				[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
			}];
		}
		if (direction == UISwipeGestureRecognizerDirectionDown)
		{
			[UIView animateWithDuration:0.2f animations:
			^{
				[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
			} completion:
			^(BOOL finished)
			{
				[[self navigationController] setNavigationBarHidden:NO animated:YES];
			}];
		}
	}
	
}
@end

