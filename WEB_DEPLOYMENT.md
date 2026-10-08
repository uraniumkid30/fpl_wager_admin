# Putting the FPLwager web apps online

This covers both web apps: the main app (`fpl_wager`, the one users see) and
the admin app (`fplboardman_admin`). Each is built into a folder of static
files, so any static host can serve it.

## What works on the web

- **Admin app:** everything.
- **Main app:** everything except **Sign in with FPL**. That sign-in reads the
  session from FPL's own login page inside the mobile app's in-app browser,
  which a web page is not allowed to do to another site. On the web the
  button explains this, and users use **Sign in with email** instead. So a
  user signs in with FPL once in the Android app, verifies their email, and
  from then on can use the website.
- **Top up on the web:** Paystack or Korapay takes over the browser tab and
  returns to the site when the user is done.

## Before you deploy: three things on the server

1. **The API needs HTTPS and a domain.** A site served over `https://` is not
   allowed to call an API on plain `http://`, and the default API address in
   both apps is a plain IP. Put the API behind a name such as
   `api.yourdomain.com` with a certificate (the Caddy example below does
   this in two lines).
2. **Tell the API which sites may call it.** Set this on the API and restart
   it, using your real addresses, with no trailing slash:

   ```
   ALLOWED_ORIGINS=https://app.yourdomain.com,https://admin.yourdomain.com
   ```

   Without it, the browser blocks every request and the apps show
   "Unable to connect".
3. **Tell the API where the main app lives**, so links in emails open it:

   ```
   APP_BASE_URL=https://app.yourdomain.com
   ```

   Set it on the API **and** on the worker, which sends the pool result
   emails.

## Build the two sites

Run these inside each Flutter project. If a project has no `web/` folder yet,
create it first with `flutter create . --platforms=web`.

```bash
# main app
flutter build web --release --dart-define=API_BASE_URL=https://api.yourdomain.com

# admin app
flutter build web --release --dart-define=API_BASE_URL=https://api.yourdomain.com
```

Each build writes the site to `build/web`. That folder is what you upload.

Both apps use `#` addresses (`https://app.yourdomain.com/#/pools`), so no
redirect or rewrite rules are needed on any host.

Do not add `--wasm` to the main app's build; its live-update connection uses
a browser library that the WebAssembly build does not support.

## Where to host them

| Option | Cost | Good for | Notes |
|---|---|---|---|
| **Cloudflare Pages** | Free | Both apps | Fast in Nigeria, free certificate and custom domain. Cloudflare Access can put the admin site behind an email check at no cost. |
| **Firebase Hosting** | Free tier | Both apps | Simple if you already use Firebase or Google Cloud. |
| **Netlify** | Free tier | Both apps | Drag and drop the folder, or one command. |
| **Vercel** | Free tier | Both apps | Works; built for other frameworks, so no advantage here. |
| **GitHub Pages** | Free | A quick test | Needs an extra build flag when served from a sub-path. |
| **Your own server** | What you already pay | Everything in one place | The same machine that runs the API can serve both sites and give the API its HTTPS. |

**Recommended:** Cloudflare Pages for both sites, with Cloudflare Access on
the admin site. If you would rather keep everything on the server you already
have, use the Caddy setup; it also solves the API's HTTPS.

### Cloudflare Pages

```bash
npm install -g wrangler
wrangler login

# in the main app project, after building
wrangler pages deploy build/web --project-name fplwager-app

# in the admin app project, after building
wrangler pages deploy build/web --project-name fplwager-admin
```

Each command prints a `*.pages.dev` address. To use your own name, open the
project in the Cloudflare dashboard, choose **Custom domains** and add
`app.yourdomain.com` (and `admin.yourdomain.com` for the other project).

To restrict the admin site: Cloudflare dashboard, **Zero Trust**, **Access**,
add an application for `admin.yourdomain.com` and allow only your
administrators' email addresses. They then confirm an emailed code before the
admin site even loads.

### Firebase Hosting

```bash
npm install -g firebase-tools
firebase login
firebase init hosting      # public directory: build/web   single-page app: yes
firebase deploy --only hosting
```

Do this once in each project. For two sites in one Firebase project, create
the second with `firebase hosting:sites:create fplwager-admin` and point it
at the admin build with `firebase target:apply hosting admin fplwager-admin`.
Add your own domain under **Hosting** in the Firebase console.

### Netlify

```bash
npm install -g netlify-cli
netlify login
netlify deploy --prod --dir=build/web
```

Run it in each project and create a new site when asked. Add your domain
under **Domain management**.

### GitHub Pages

Build with the repository name as the base path, then publish `build/web`
from a `gh-pages` branch:

```bash
flutter build web --release --base-href /your-repo-name/ \
  --dart-define=API_BASE_URL=https://api.yourdomain.com
```

### Your own server with Caddy

Copy each `build/web` folder to the server, for example to
`/var/www/fplwager-app` and `/var/www/fplwager-admin`. Point three DNS
records (`api`, `app`, `admin`) at the server, install Caddy and use this
`Caddyfile`. Caddy gets and renews the certificates itself.

```
api.yourdomain.com {
    reverse_proxy 127.0.0.1:8080
}

app.yourdomain.com {
    root * /var/www/fplwager-app
    file_server
}

admin.yourdomain.com {
    root * /var/www/fplwager-admin
    file_server
}
```

Change `8080` to the port the API listens on. The API's live-update
connection (WebSocket) passes through `reverse_proxy` without extra settings.

## After deploying

1. Open the admin site and sign in. If it says "Unable to connect", check
   `ALLOWED_ORIGINS` and that the API address in the build starts with
   `https://`.
2. In the Paystack and Korapay dashboards, set the webhook to
   `https://api.yourdomain.com/v1/payments/webhooks/paystack` (and
   `.../korapay`). The same address receives both top-ups and withdrawal
   transfers.
3. Rebuild the Android app with the same `API_BASE_URL` so the phone and the
   websites use one server.
