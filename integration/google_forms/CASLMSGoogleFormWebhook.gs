/**
 * CASLMS Google Forms submission bridge.
 *
 * Required Script Properties:
 * - CASLMS_ENDPOINT
 * - CASLMS_ASSESSMENT_ID
 * - CASLMS_WEBHOOK_SECRET
 *
 * The Google Form must collect verified email addresses. Install the
 * `onCaslmsFormSubmit` function as a From form -> On form submit trigger.
 */
function onCaslmsFormSubmit(event) {
  if (!event || !event.response) {
    throw new Error('This function must run from a Google Form submit trigger.');
  }

  const properties = PropertiesService.getScriptProperties();
  const endpoint = properties.getProperty('CASLMS_ENDPOINT');
  const assessmentId = properties.getProperty('CASLMS_ASSESSMENT_ID');
  const webhookSecret = properties.getProperty('CASLMS_WEBHOOK_SECRET');

  if (!endpoint || !assessmentId || !webhookSecret) {
    throw new Error('CASLMS Script Properties are incomplete.');
  }

  const studentEmail = String(
    event.response.getRespondentEmail() || '',
  ).trim().toLowerCase();

  const responseId = String(event.response.getId() || '').trim();

  if (!studentEmail) {
    throw new Error(
      'No verified email was received. Enable Collect email addresses in the form settings.',
    );
  }

  if (!responseId) {
    throw new Error('Google Forms did not provide a response ID.');
  }

  const response = UrlFetchApp.fetch(endpoint, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify({
      action: 'google_form_callback',
      webhookSecret: webhookSecret,
      assessmentId: assessmentId,
      studentEmail: studentEmail,
      responseId: responseId,
    }),
    muteHttpExceptions: true,
  });

  const status = response.getResponseCode();
  const body = response.getContentText();

  if (status < 200 || status >= 300) {
    throw new Error('CASLMS rejected the response (' + status + '): ' + body);
  }

  console.log('CASLMS submission recorded: ' + body);
}

