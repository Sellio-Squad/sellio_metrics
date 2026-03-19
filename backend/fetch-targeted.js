const fs = require('fs');
fetch('https://sellio-metrics.abdoessam743.workers.dev/api/sync/github', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ repos: ['sellio_metrics'], prNumbers: [57] })
})
.then(r => r.text())
.then(d => {
  fs.writeFileSync('result.json', d);
  console.log("Done");
})
.catch(e => {
  fs.writeFileSync('result.json', String(e));
  console.log("Error");
});
