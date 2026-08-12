const https = require('https');

const API_KEY = "AIzaSyCXzpvcdGJARb7WcDzXtcwzLEUMwt5bRjw";
const PROJECT_ID = "g-wash-ng";

function postJson(urlStr, data) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const body = JSON.stringify(data);
    const req = https.request(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body)
      }
    }, (res) => {
      let resData = '';
      res.on('data', chunk => resData += chunk);
      res.on('end', () => {
        try {
          resolve({ statusCode: res.statusCode, body: JSON.parse(resData) });
        } catch (e) {
          resolve({ statusCode: res.statusCode, body: resData });
        }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

async function run() {
  console.log("🧹 Resetting Admin Financial Data...");

  // 1. Fetch all documents in payments collection
  const listPaymentsUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/payments?key=${API_KEY}`;
  const paymentsRes = await postJson(listPaymentsUrl, {});

  // 2. Fetch all documents in jobs collection and reset isPaid & status for test jobs
  const queryJobsUrl = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery?key=${API_KEY}`;
  const jobsQuery = {
    structuredQuery: {
      from: [{ collectionId: "jobs" }]
    }
  };
  const jobsRes = await postJson(queryJobsUrl, jobsQuery);

  if (Array.isArray(jobsRes.body)) {
    for (const item of jobsRes.body) {
      if (item.document) {
        const docName = item.document.name;
        const fields = item.document.fields || {};
        
        // Remove static payment data from old test jobs
        const updateUrl = `https://firestore.googleapis.com/v1/${docName}?updateMask.fieldPaths=isPaid&updateMask.fieldPaths=paymentStatus&key=${API_KEY}`;
        await postJson(updateUrl, {
          fields: {
            isPaid: { booleanValue: false },
            paymentStatus: { stringValue: "unpaid" }
          }
        });
        console.log(`✅ Cleared payment status on job document: ${docName.split('/').pop()}`);
      }
    }
  }

  console.log("🎉 Admin financial data successfully cleared and reset to ₦0!");
}

run().catch(console.error);
