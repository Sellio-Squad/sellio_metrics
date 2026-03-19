const fs = require('fs');
fetch('https://sellio-metrics.abdoessam743.workers.dev/api/sync/github', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ repos: ['sellio_metrics'] }) 
})
.then(r => r.text())
.then(d => {
  fs.writeFileSync('result-full.json', d);
  console.log("Done");
})
.catch(e => {
  fs.writeFileSync('result-full.json', String(e));
  console.log("Error");
});
