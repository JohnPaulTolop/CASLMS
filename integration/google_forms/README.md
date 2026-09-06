# CASLMS Google Forms tracking

1. Create the assessment in CASLMS and select **Google Form**.
2. In Google Forms, enable **Collect email addresses**. Prefer verified email and restrict the form to the school domain when available.
3. Open **Extensions > Apps Script** from that form and paste `CASLMSGoogleFormWebhook.gs`.
4. In Apps Script, open **Project Settings > Script Properties** and add:
   - `CASLMS_ENDPOINT`: `https://jymjlterjhznsxrwpjqz.supabase.co/functions/v1/assessment-submission`
   - `CASLMS_ASSESSMENT_ID`: the Firestore assessment document ID
   - `CASLMS_WEBHOOK_SECRET`: the same secret stored in Supabase as `GOOGLE_FORM_WEBHOOK_SECRET`
5. Open **Triggers**, add a trigger for `onCaslmsFormSubmit`, choose **From form** and **On form submit**, then authorize it.

CASLMS records completion only after this trigger reports a response from an active student enrolled in the assessment's course.
