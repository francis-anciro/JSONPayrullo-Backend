# JSON Payrullo

JSON Payrullo is a comprehensive HR and Payroll solution designed to centralize and simplify employee management through a secure relational database system.

The platform enables administrators to:

- Maintain detailed digital employee profiles  
- Assign departments and job positions  
- Manage employment types  
- Track shifts and attendance records  
- Process payroll using accurate, up-to-date personnel data  

By integrating employee records with automated tracking, the system ensures data consistency and reliable payroll processing.

---

# Requirements:
- Frontend of this project: <a href="https://github.com/francis-anciro/JSONPayrullo-Backend" target="_blank"> Download here </a>

---

## Tech Stack

- **Frontend:** Vite + React  
- **Backend:** PHP  
- **Database:** MySQL  

---

## Setup

1. Download the ZIP file.
2. Extract the files.
3. Move the folder into `xampp/htdocs/`.
4. Start **Apache** and **MySQL** in XAMPP.
5. Import .sql file inside DB/ to your database
   
---

# Note

- Check the port number shown in your Vite URL.  
  Example:
  
- If the port is not `5173`, update this line in app/public/index.php to match port number

Change:
```php
header("Access-Control-Allow-Origin: http://localhost:<--YOUR PORT NUMBER HERE-->");
```
Make a folder named config and make a config.php file inside with these contents:
```
<?php

define('DB_HOST', 'localhost');
define('DB_USER', '<YOUR USERNAME>');
define('DB_PASS', '<YOUR PASSWORD>');
define('DB_NAME', 'json_payrullo');

define('APPROOT', dirname(dirname(__FILE__)));

define('URLROOT', 'http://localhost/JSONPayrullo');

define('SITENAME', 'JSON Payrullo');
```
