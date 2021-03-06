/*
 * Copyright 2011 Marco Abundo
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "ButtonPeoplePicker.h"

@interface ButtonPeoplePicker () // Private methods

- (void)layoutNameButtons;
- (void)addPersonToGroup:(NSDictionary *)personDictionary;
- (void)removePersonFromGroup:(NSDictionary *)personDictionary;
- (void)displayAddPersonViewController;

@end


@implementation ButtonPeoplePicker

@synthesize delegate, group;

#pragma mark -
#pragma mark Lifecycle methods

// Perform additional initialization after the nib file is loaded
- (void)viewDidLoad 
{
    [super viewDidLoad];

	addressBook = ABAddressBookCreate();
	
	people = (NSArray *)ABAddressBookCopyArrayOfAllPeople(addressBook);
    
    group = [[NSMutableArray alloc] init];
	
	// Create a filtered list that will contain people for the search results table.
	filteredPeople = [[NSMutableArray alloc] init];
	
	// Add a "textFieldDidChange" notification method to the text field control.
	[searchField addTarget:self action:@selector(textFieldDidChange) forControlEvents:UIControlEventEditingChanged];
	
	[self layoutNameButtons];
}

- (void)dealloc
{
	delegate = nil;
	[deleteLabel release];
	[buttonView release];
	[uiTableView release];
	[searchField release];
    [doneButton release];
	[people release];
    [group release];
	CFRelease(addressBook);
	[filteredPeople release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Respond to touch and become first responder.

- (BOOL)canBecomeFirstResponder
{
	return YES;
}

#pragma mark -
#pragma mark Button actions

// Action receiver for the clicking of Done button
-(IBAction)doneClick:(id)sender
{
	[delegate buttonPeoplePickerDidFinish:self];
}

// Action receiver for the clicking of Cancel button
- (IBAction)cancelClick:(id)sender
{
	[group removeAllObjects];
	[delegate buttonPeoplePickerDidFinish:self];
}

// Action receiver for the selecting of name button
- (IBAction)buttonSelected:(id)sender {

	selectedButton = (UIButton *)sender;
	
	// Clear other button states
	for (UIView *subview in buttonView.subviews)
    {
		if ([subview isKindOfClass:[UIButton class]] && subview != selectedButton)
        {
			((UIButton *)subview).selected = NO;
		}
	}

	if (selectedButton.selected)
    {
		selectedButton.selected = NO;
		deleteLabel.hidden = YES;
	}
	else
    {
		selectedButton.selected = YES;
		deleteLabel.hidden = NO;
	}

	[self becomeFirstResponder];
}

#pragma mark -
#pragma mark UIKeyInput protocol methods

- (BOOL)hasText
{
	return NO;
}

- (void)insertText:(NSString *)text {}

- (void)deleteBackward
{	
	// Hide the delete label
	deleteLabel.hidden = YES;

	NSString *name = selectedButton.titleLabel.text;
	NSInteger identifier = selectedButton.tag;
	
	NSArray *personArray = (NSArray *)ABAddressBookCopyPeopleWithName(addressBook, (CFStringRef)name);
	
	ABRecordRef person = [personArray lastObject];

	ABRecordID abRecordID = ABRecordGetRecordID(person);

	NSDictionary *personDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
									  [NSNumber numberWithInt:abRecordID], @"abRecordID",
									  [NSNumber numberWithInt:identifier], @"valueIdentifier", nil];

	[self removePersonFromGroup:personDictionary];
	
	[personArray release];
}

#pragma mark -
#pragma mark UITableViewDataSource protocol methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	// do we have search text? if yes, are there search results? if yes, return number of results, otherwise, return 1 (add email row)
	// if there are no search results, the table is empty, so return 0
	return searchField.text.length > 0 ? MAX( 1, filteredPeople.count ) : 0 ;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{	
	static NSString *kCellID = @"cellID";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellID];
	
	if (cell == nil)
    {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kCellID] autorelease];
	}
    
    cell.accessoryType = UITableViewCellAccessoryNone;
		
	// If this is the last row in filteredPeople, take special action
	if (filteredPeople.count == indexPath.row)
    {
		cell.textLabel.text	= @"Add Person";
		cell.detailTextLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	else
    {
		NSDictionary *personDictionary = [filteredPeople objectAtIndex:indexPath.row];
		
		ABRecordID abRecordID = (ABRecordID)[[personDictionary valueForKey:@"abRecordID"] intValue];
		
		ABRecordRef abPerson = ABAddressBookGetPersonWithRecordID(addressBook, abRecordID);
		
		ABMultiValueIdentifier identifier = [[personDictionary valueForKey:@"valueIdentifier"] intValue];
		
		{
			NSString *string = (NSString *)ABRecordCopyCompositeName(abPerson);
			cell.textLabel.text = string;
			[string release];
		}
		
		ABMultiValueRef emailProperty = ABRecordCopyValue(abPerson, kABPersonEmailProperty);
		
		if (emailProperty)
        {
			CFIndex index = ABMultiValueGetIndexForIdentifier(emailProperty, identifier);
			
			if (index != -1)
            {
				NSString *email = (NSString *)ABMultiValueCopyValueAtIndex(emailProperty, index);
				cell.detailTextLabel.text = email;
				[email release];
			}
			else
            {
				cell.detailTextLabel.text = nil;
			}
		}
		
		if (emailProperty) CFRelease(emailProperty);
	}
	
	return cell;
}

#pragma mark -
#pragma mark UITableViewDelegate protocol method

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView setHidden:YES];

	// Handle the special case
	if (indexPath.row == filteredPeople.count)
    {
		[self displayAddPersonViewController];
	}
	else
    {
		NSDictionary *personDictionary = [filteredPeople objectAtIndex:indexPath.row];
		
		[self addPersonToGroup:personDictionary];
	}

	searchField.text = nil;
}

#pragma mark -
#pragma mark Update the filteredPeople array based on the search text.

- (void)filterContentForSearchText:(NSString*)searchText
{
	// First clear the filtered array.
	[filteredPeople removeAllObjects];

	// beginswith[cd] predicate
	NSPredicate *beginsPredicate = [NSPredicate predicateWithFormat:@"(SELF beginswith[cd] %@)", searchText];

	/*
	 Search the main list for people whose firstname OR lastname OR organization matches searchText; add items that match to the filtered array.
	 */
	
	for (id person in people)
    {
		// Access the person's email addresses (an ABMultiValueRef)
		ABMultiValueRef emailsProperty = ABRecordCopyValue(person, kABPersonEmailProperty);
		
		if (emailsProperty)
        {
			// Iterate through the email address multivalue
			for (CFIndex index = 0; index < ABMultiValueGetCount(emailsProperty); index++)
            {
				NSString *firstName = (NSString *)ABRecordCopyValue(person, kABPersonFirstNameProperty);
				NSString *lastName = (NSString *)ABRecordCopyValue(person, kABPersonLastNameProperty);
				NSString *organization = (NSString *)ABRecordCopyValue(person, kABPersonOrganizationProperty);
				NSString *emailString = (NSString *)ABMultiValueCopyValueAtIndex(emailsProperty, index);
				
				// Match by firstName, lastName, organization or email address
				if ([beginsPredicate evaluateWithObject:firstName] ||
					[beginsPredicate evaluateWithObject:lastName] ||
					[beginsPredicate evaluateWithObject:organization] ||
					[beginsPredicate evaluateWithObject:emailString])
                {
					// Get the address identifier for this address
					ABMultiValueIdentifier identifier = ABMultiValueGetIdentifierAtIndex(emailsProperty, index);
					
					ABRecordID abRecordID = ABRecordGetRecordID(person);
					
					NSDictionary *personDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
													 [NSNumber numberWithInt:abRecordID], @"abRecordID",
													 [NSNumber numberWithInt:identifier], @"valueIdentifier", nil];

					// Add each personDictionary to filteredPeople
					[filteredPeople addObject:personDictionary];
				}

				[firstName release];
				[lastName release];
				[organization release];
				[emailString release];
			 }
			
			 CFRelease(emailsProperty);
		}
	}
}

#pragma mark -
#pragma mark textFieldDidChange notification method to the searchField control.

- (void)textFieldDidChange
{
	if (searchField.text.length > 0)
    {
		[uiTableView setHidden:NO];
		[self filterContentForSearchText:searchField.text];
		[uiTableView reloadData];
	}
	else
    {
		[uiTableView setHidden:YES];
	}
}

#pragma mark -
#pragma mark Add and remove a person to/from the group

- (void)addPersonToGroup:(NSDictionary *)personDictionary
{
    ABRecordID abRecordID = (ABRecordID)[[personDictionary valueForKey:@"abRecordID"] intValue];
    
    // Check for an existing entry for this person, if so remove it
    for (NSDictionary *personDict in group)
    {
        if ((abRecordID == (ABRecordID)[[personDict valueForKey:@"abRecordID"] intValue]))
        {
            [group removeObject:personDict];
            break;
        }
    }
    
    [group addObject:personDictionary];
    [self layoutNameButtons];
}

- (void)removePersonFromGroup:(NSDictionary *)personDictionary
{
	[group removeObject:personDictionary];	
	[self layoutNameButtons];
}

#pragma mark -
#pragma mark Update Person info

-(void)layoutNameButtons
{
	// Remove existing buttons
	for (UIView *subview in buttonView.subviews)
    {
		if ([subview isKindOfClass:[UIButton class]])
        {
			[subview removeFromSuperview];
		}
	}
	
	CGFloat PADDING = 5.0;
	CGFloat maxWidth = buttonView.frame.size.width - PADDING;
	CGFloat xPosition = PADDING;
	CGFloat yPosition = PADDING;

	for (int i = 0; i < group.count; i++)
    {
		NSDictionary *personDictionary = (NSDictionary *)[group objectAtIndex:i];
		
		ABRecordID abRecordID = (ABRecordID)[[personDictionary valueForKey:@"abRecordID"] intValue];

		ABRecordRef abPerson = ABAddressBookGetPersonWithRecordID(addressBook, abRecordID);

		NSString *name = (NSString *)ABRecordCopyCompositeName(abPerson);
		
		ABMultiValueIdentifier identifier = [[personDictionary valueForKey:@"valueIdentifier"] intValue];
		
		// Create the button image
		UIImage *image = [UIImage imageNamed:@"ButtonCorners.png"];
		image = [image stretchableImageWithLeftCapWidth:3.5 topCapHeight:3.5];
		
		UIImage *image2 = [UIImage imageNamed:@"bottom-button-bg.png"];
		image2 = [image2 stretchableImageWithLeftCapWidth:3.5 topCapHeight:3.5];

		// Create the button
		UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
		[button setTitle:name forState:UIControlStateNormal];
		
		// Use the identifier as a tag for future reference
		[button setTag:identifier];
		[button.titleLabel setFont:[UIFont systemFontOfSize:16.0]];
		[button setBackgroundImage:image forState:UIControlStateNormal];
		[button setBackgroundImage:image2 forState:UIControlStateSelected];
		[button addTarget:self action:@selector(buttonSelected:) forControlEvents:UIControlEventTouchUpInside];

		// Get the width and height of the name string given a font size
		CGSize nameSize = [name sizeWithFont:[UIFont systemFontOfSize:16.0]];

		if ((xPosition + nameSize.width + PADDING) > maxWidth)
        {
			// Reset horizontal position to left edge of superview's frame
			xPosition = PADDING;
			
			// Set vertical position to a new 'line'
			yPosition += nameSize.height + PADDING;
		}
		
		// Create the button's frame
		CGRect buttonFrame = CGRectMake(xPosition, yPosition, nameSize.width + (PADDING * 2), nameSize.height);
		[button setFrame:buttonFrame];
		[buttonView addSubview:button];
		
		// Calculate xPosition for the next button in the loop
		xPosition += button.frame.size.width + PADDING;
		
		// Calculate the y origin for the delete label
		CGRect labelFrame = deleteLabel.frame;
		labelFrame.origin.y = yPosition + button.frame.size.height + PADDING;
		[deleteLabel setFrame:labelFrame];
		
		[name release];
	}
    
    if (group.count > 0)
    {
        [doneButton setEnabled:YES];
    }
    else
    {
        [doneButton setEnabled:NO];
    }
	
	[buttonView setHidden:NO];
	[searchField becomeFirstResponder];
}

#pragma mark -
#pragma mark display the AddPersonViewController modally

-(void)displayAddPersonViewController
{	
	AddPersonViewController *addPersonViewController = [[AddPersonViewController alloc] init];
	[addPersonViewController setInitialText:searchField.text];
	[addPersonViewController setDelegate:self];
	[self presentModalViewController:addPersonViewController animated:YES];
	[addPersonViewController release];
}

#pragma mark -
#pragma mark AddPersonViewControllerDelegate method

- (void)addPersonViewControllerDidFinish:(AddPersonViewController *)controller
{
	NSString *firstName = [NSString stringWithString:controller.firstName];
	NSString *lastName = [NSString stringWithString:controller.lastName];
	NSString *email = [NSString stringWithString:controller.email];

	ABRecordRef personRef = ABPersonCreate();

	ABRecordSetValue(personRef, kABPersonFirstNameProperty, firstName, nil);

	if (lastName && (lastName.length > 0))
    {
		ABRecordSetValue(personRef, kABPersonLastNameProperty, lastName, nil);
	}
	
	if (email && (email.length > 0))
	{
		ABMutableMultiValueRef emailProperty = ABMultiValueCreateMutable(kABPersonEmailProperty);
		ABMultiValueAddValueAndLabel(emailProperty, email, kABHomeLabel, nil);
		ABRecordSetValue(personRef, kABPersonEmailProperty, emailProperty, nil);
		CFRelease(emailProperty);
	}
		
	// Add the person to the address book
	ABAddressBookAddRecord(addressBook, personRef, nil);
	
	// Save changes to the address book
	ABAddressBookSave(addressBook, nil);

	ABRecordID abRecordID = ABRecordGetRecordID(personRef);

	NSDictionary *personDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
									 [NSNumber numberWithInt:abRecordID], @"abRecordID",
									 [NSNumber numberWithInt:0], @"valueIdentifier", nil];

	CFRelease(personRef);
	
	[self addPersonToGroup:personDictionary];
	
	[self dismissModalViewControllerAnimated:YES];
}

@end