# VIVID+ Customer App Blueprint

## Purpose

The customer app helps users discover businesses, manage memberships, earn rewards, receive personalized offers, view events, and interact with every VIVID+ business from one mobile application.

---

## Main Customer Navigation

The bottom navigation contains:

- Home
- Wallet
- Discover
- Notifications
- Profile

---

## Screen 1: Splash Screen

Purpose:

Introduce the VIVID+ brand while the app loads.

Elements:

- VIVID+ logo
- Purple animated glow
- Dark background
- Loading indicator

Behavior:

- Check whether the customer is already logged in
- If logged in, open Home
- If not logged in, open Welcome

---

## Screen 2: Welcome Screen

Purpose:

Explain the value of joining VIVID+.

Elements:

- Headline
- Short customer benefit message
- Create Account button
- Sign In button
- Continue as Guest option

Main message:

One app. Every membership. Better rewards.

---

## Screen 3: Customer Registration

Required fields:

- First name
- Last name
- Mobile phone number
- Email
- Birthday
- Password
- Confirm password

Optional fields:

- Referral code
- Preferred interests

Required agreements:

- Terms of Service
- Privacy Policy
- Marketing permission
- Push notification permission request after registration

Security:

- Verify email or phone
- Prevent duplicate accounts
- Secure password requirements
- Rate limit registration attempts

---

## Screen 4: Customer Login

Login methods:

- Email and password
- Phone and verification code
- Apple Sign In
- Google Sign In

Features:

- Forgot password
- Remember device
- Secure session handling

---

## Screen 5: Customer Home

Purpose:

Give the customer the most important information immediately.

Elements:

- Greeting
- Current city or location
- Membership summary
- Total available rewards
- Featured nearby offer
- Upcoming event
- Favorite businesses
- Recent activity
- Recommended businesses

Primary actions:

- Open membership wallet
- View rewards
- View event
- Get directions
- Activate offer

Design:

- Premium dark interface
- Purple gradient highlights
- Glass cards
- Smooth point animations
- No gold main theme

---

## Screen 6: Membership Wallet

Purpose:

Store every customer membership in one place.

Elements:

- Business memberships
- Membership tier
- Point balance
- Digital QR membership card
- Reward progress
- Last visit
- Expiring rewards

Actions:

- Open membership
- Show QR
- View rewards
- View activity
- Leave membership

Security:

The QR code must use a secure temporary token and must not expose the customer database ID directly.

---

## Screen 7: Membership Details

Elements:

- Business logo
- Business name
- Membership status
- Customer name
- Membership tier
- Current points
- Reward progress
- Secure QR code
- Available rewards
- Recent activity
- Business contact information
- Directions

---

## Screen 8: Rewards

Reward categories:

- Available
- In Progress
- Redeemed
- Expired

Each reward displays:

- Reward name
- Required points
- Current progress
- Expiration date
- Business
- Terms

Actions:

- View reward
- Activate reward
- Show redemption code

Important rule:

A customer cannot complete a reward redemption alone.

An employee must confirm the redemption.

---

## Screen 9: Promotions

Elements:

- Active offers
- Personalized offers
- Nearby offers
- Limited-time offers
- New customer offers
- Win-back offers

Each promotion displays:

- Business
- Offer
- Expiration
- Eligibility
- Distance
- Directions
- Activate button

Promotion states:

- Available
- Activated
- Redeemed
- Expired
- Not eligible

---

## Screen 10: Events

Elements:

- Upcoming events
- Nearby events
- Saved events
- Business events
- Event categories

Event details include:

- Event image
- Event title
- Business
- Date
- Time
- Address
- Distance
- Description
- Admission information
- Save event
- Directions
- Share event

---

## Screen 11: Discover

Purpose:

Help customers find VIVID+ businesses.

Filters:

- Nearby
- Restaurants
- Lounges
- Coffee shops
- Barbers
- Gyms
- Retail
- Car washes
- Events
- Best rewards

Business cards display:

- Logo
- Business name
- Category
- Distance
- Current promotion
- Upcoming event
- Membership status

---

## Screen 12: Notifications

Notification categories:

- Offers
- Events
- Rewards
- Points
- Membership
- Nearby
- System

Actions:

- Open related screen
- Mark as read
- Delete
- Manage preferences

---

## Screen 13: Activity History

Activity types:

- Purchases
- Points earned
- Points adjusted
- Rewards redeemed
- Promotions redeemed
- Membership joined
- Referrals

Each activity displays:

- Date and time
- Business
- Transaction type
- Amount
- Points change
- Final balance

---

## Screen 14: Referrals

Elements:

- Personal referral code
- Share link
- QR referral code
- Referral reward
- Successful referrals
- Pending referrals

Fraud controls:

- No self-referrals
- Device and account checks
- Reward only after qualifying transaction
- Business-defined referral rules

---

## Screen 15: Customer Profile

Elements:

- Name
- Profile photo
- Phone
- Email
- Birthday
- Interests
- Favorite businesses
- Saved payment methods in future
- Privacy controls

---

## Screen 16: Settings

Options:

- Push notifications
- SMS notifications
- Email notifications
- Nearby offers
- Location permission
- Marketing preferences
- Language
- Security
- Delete account
- Sign out

---

## Customer Permissions

The app may request:

- Push notification permission
- Location permission
- Camera permission for joining or referral QR scanning
- Photo permission only when uploading a profile image

Rules:

- Explain why each permission is needed
- Never block basic account access because optional permission was denied
- Allow the customer to change preferences later
- Follow privacy and platform requirements

---

## Customer Notification Rules

The customer must control:

- Offer notifications
- Event notifications
- Reward notifications
- Birthday messages
- Nearby offers
- SMS
- Email

Frequency controls:

- Maximum promotional push notifications per business per day
- Quiet hours
- Campaign cooldowns
- Nearby-offer cooldowns
- Duplicate-message prevention

---

## Customer Geofencing Experience

Business location:

7216 W Colonial Dr, Orlando, FL 32818

Example zones:

- 10-mile discovery zone
- 5-mile interest zone
- 1-mile arrival zone

Example nearby offer:

You are close to Vivid Lounge. Open your surprise offer before it expires.

Rules:

- Customer must opt in
- Only send when an eligible campaign exists
- Do not repeatedly notify the same customer
- Respect business hours
- Respect quiet hours
- Track delivery, activation, visit, redemption, and revenue
- Allow the customer to disable nearby offers

---

## Complete Customer Journey

Customer scans business join QR.

Customer opens VIVID+.

Customer creates an account.

Customer joins the business membership.

Customer receives a welcome notification.

Customer sees the membership in Wallet.

Customer visits the business.

Employee scans the secure customer QR.

Employee records the transaction.

Points are awarded.

Customer receives a points notification.

Customer later receives an event or promotion.

Customer activates the offer.

Customer visits the business.

Employee confirms the offer redemption.

The sale is connected to the campaign.

The business owner sees the campaign results.

---

## Customer App Success Measures

Track:

- Registrations
- Verified accounts
- Membership joins
- Monthly active customers
- Notification permission rate
- Location permission rate
- Offer activation rate
- Offer redemption rate
- Repeat visit rate
- Referral conversion
- Reward redemption
- Revenue attributed to campaigns
- Customer retention

---

## Customer App Completion Definition

The customer app is complete only when a real customer can:

- Register securely
- Join a business
- View a secure membership QR
- Earn points from an employee-confirmed transaction
- View rewards
- Receive notifications
- Activate an offer
- Redeem through an employee
- View transaction history
- Manage permissions and privacy
- Use the experience reliably on iPhone and Android
