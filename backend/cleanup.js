const mysql = require('mysql2');
require('dotenv').config();

const db = mysql.createConnection({
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'devvault'
});

db.connect(err => {
  if (err) { console.log('❌ DB connection failed:', err); return; }
  console.log('✅ Connected to MySQL');
  
  db.query('DELETE FROM users WHERE password IS NULL OR password = ""', (err, result) => {
    if (err) console.log('❌ Error:', err);
    else console.log(`✅ Deleted ${result.affectedRows} broken user(s)`);
    
    db.query('DELETE FROM users WHERE email = "alex@univ.com"', (err, result) => {
      if (err) console.log('❌ Error:', err);
      else console.log(`✅ Deleted alex@univ.com (${result.affectedRows} row(s))`);
      
      db.end();
      console.log('🎉 Cleanup done! Now restart the backend and register a fresh user.');
    });
  });
});