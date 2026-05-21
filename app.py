
from http.server import HTTPServer, BaseHTTPRequestHandler

import json, os

class Handler(BaseHTTPRequestHandler):

    def do_GET(self):

        if self.path == '/health':

            self.send_response(200)

            self.send_header('Content-Type', 'application/json')

            self.end_headers()

            self.wfile.write(json.dumps({"status": "healthy"}).encode())

        else:

            self.send_response(200)

            self.send_header('Content-Type', 'text/html')

            self.end_headers()

            html = """

            <!DOCTYPE html>

            <html>

            <head><title>DevOps Assessment</title>

            <style>

              body { font-family: Arial, sans-serif; display: flex; justify-content: center;

                     align-items: center; height: 100vh; margin: 0; background: #0f1923; color: white; }

              .card { text-align: center; padding: 40px; border: 1px solid #ff9900;

                      border-radius: 12px; max-width: 500px; }

              h1 { color: #ff9900; } .badge { background: #ff9900; color: black;

              padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: bold; }

            </style></head>

            <body><div class="card">

              <span class="badge">AWS &#x2713;</span>

              <h1>Thank you for this Assessment</h1>

              <p>Containerized app running on AWS</p>

              <p style="color:#aaa;font-size:13px;">EC2 &#x2192; Private Subnet &#x2192; RDS PostgreSQL</p>

            </div></body></html>

            """

            self.wfile.write(html.encode())

    def log_message(self, format, *args):

        pass

if __name__ == '__main__':

    port = int(os.environ.get('PORT', 8080))

    print(f"Server running on port {port}")

    HTTPServer(('', port), Handler).serve_forever()

