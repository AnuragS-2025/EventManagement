# Event and Ticket Management System - Backend

This is the Node.js Express backend for the Event and Ticket Management System.

## Prerequisites
- Node.js installed
- MySQL installed and running

## Database Setup (MySQL Command Line)
1. Open your terminal or correct command prompt.
2. Login to MySQL:
   ```bash
   mysql -u root -p
   ```
3. Source the `schema.sql` file provided in the main directory:
   ```sql
   source C:/Users/anura/OneDrive/Desktop/Event and Ticket Management  System/schema.sql;
   ```
   *Note: Ensure the path is correct or simply be in the directory where `schema.sql` is when you run `mysql -u root -p < schema.sql`.*

## Backend Setup
1. Open a terminal in the `backend` folder.
2. Install dependencies:
   ```bash
   npm install
   ```
   *Note: If PowerShell throws an "Execution Policy" error, run this inside Command Prompt (`cmd`) instead.*

3. Configure Environment Variables:
   - Open the `backend/.env` file.
   - Update `DB_PASSWORD` to your actual MySQL root password.

4. Run the Server:
   ```bash
   npm start
   ```
   The server will run on `http://localhost:5000`.

## API Endpoints Overview
- **Auth:** `POST /api/auth/register`, `POST /api/auth/login`
- **Events:** `GET /api/events`, `POST /api/events` (Admin), `PUT /api/events/:id` (Admin), `DELETE /api/events/:id` (Admin)
- **Bookings:** `POST /api/bookings` (Auth), `GET /api/bookings/my-bookings` (Auth)
