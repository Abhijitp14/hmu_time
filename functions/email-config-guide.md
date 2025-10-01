# Email Configuration Guide for HMU Time

## Step 1: Choose Email Service

### Option A: Gmail (Recommended for Development)
1. **Enable 2-Factor Authentication** on your Gmail account
2. **Generate App Password**:
   - Go to [Google Account Settings](https://myaccount.google.com)
   - Security → 2-Step Verification → App passwords
   - Generate password for "Mail"
3. **Update .env file**:
   ```
   EMAIL_USER=your-gmail@gmail.com
   EMAIL_PASSWORD=your-16-digit-app-password
   COMPANY_EMAIL=hr@yourcompany.com
   ```

### Option B: SendGrid (Recommended for Production)
1. **Create SendGrid Account**: [SendGrid](https://sendgrid.com)
2. **Create API Key**: Settings → API Keys → Create API Key
3. **Update .env file**:
   ```
   SENDGRID_API_KEY=your-sendgrid-api-key
   COMPANY_EMAIL=hr@yourcompany.com
   ```

## Step 2: Update Functions Configuration

### For Gmail:
The current setup is ready. Just update the .env file with your credentials.

### For SendGrid:
Update `functions/src/index.ts` to use SendGrid instead of nodemailer.

## Step 3: Deploy Functions

```bash
cd functions
firebase deploy --only functions
```

## Step 4: Test Email Functionality

1. Create a test employee from the admin dashboard
2. Check the Firebase Functions logs:
   ```bash
   firebase functions:log
   ```
3. Verify the employee receives the welcome email

## Security Notes

- Never commit .env file to version control
- Use strong app passwords
- Monitor email usage to avoid spam flags
- Consider using a dedicated email service for production

## Troubleshooting

### Common Issues:
1. **"Invalid login"**: Check app password generation
2. **"Blocked sign-in attempt"**: Enable "Less secure app access" or use App Password
3. **"Daily limit exceeded"**: Switch to SendGrid for higher limits
4. **Emails in spam**: Configure SPF/DKIM records for your domain

### Debug Commands:
```bash
# View function logs
firebase functions:log

# Test function locally
firebase functions:shell
```
