# LILO — Serverless Habit Tracker

A serverless CRUD web application for building and keeping daily habits. Add, edit, and remove habits, choose which days of the week each one runs, and earn streaks for staying consistent.

**Live:** [lilo.juliointeriano.cloud](https://lilo.juliointeriano.cloud)

---

## Features

- **Full CRUD** — create, read, update, and delete habits
- **Custom schedules** — pick which days of the week each habit is active
- **Streak tracking** — complete your daily habits to build and maintain streaks
- **User accounts** — sign up and log in with email verification, so habits are private per user

---

## Architecture

```
Browser
  │
  ▼
CloudFront ──serves──▶ S3 (static front end)
  │
  │ (API calls)
  ▼
API Gateway ──routes──▶ Lambda (Python) ──reads/writes──▶ DynamoDB (habits + streaks)
```

The front end is hosted in **S3** and served globally over HTTPS by **CloudFront**. User actions call an **API Gateway** endpoint, which routes to **Lambda** functions (Python) that handle the logic and read/write habit and streak data in **DynamoDB**. User authentication is handled with email-verified login.

## Why serverless?

Habit-tracking traffic is light and spiky — a few interactions per user per day. A serverless architecture scales to zero when idle, so there are no always-on server costs; the app costs pennies to run.

## Services used

| Service       | Role                                                      |
|---------------|-----------------------------------------------------------|
| Amazon S3     | Hosts the static front end                                |
| CloudFront    | Serves the front end globally over HTTPS                  |
| API Gateway   | Secure endpoint — routes requests to Lambda               |
| AWS Lambda    | Python functions running the CRUD and streak logic        |
| Amazon DynamoDB | Stores habits, schedules, and streak data               |
| Authentication | Email-verified user login (accounts are private per user)|

---

## Roadmap

- **Email reminders** — nudge users about pending habits (email over SMS to keep costs low)
- **UI overhaul** — a more engaging, "Duolingo-style" experience to drive daily return and long-term retention
- **Expanded gamification** — richer streak mechanics and motivation to keep habits going

---

## About

Built as part of a self-directed transition into cloud engineering. The goal was a real, deployed, serverless application exercising the core AWS building blocks — S3, CloudFront, API Gateway, Lambda, and DynamoDB — end to end.

**Author:** Julio Interiano · [github.com/Interiano](https://github.com/Interiano)
