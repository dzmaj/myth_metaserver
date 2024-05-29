from http.server import BaseHTTPRequestHandler, HTTPServer

import json

# Define the RankResponseBody class
class RankResponseBody:
  def __init__(self, ranks):
    self.ranks = ranks

# Handler class for processing requests
class RankRequestHandler(BaseHTTPRequestHandler):
  def do_GET(self):
    # Extract user ID from the path
    user_id_str = self.path.split("/")[-1]
    try:
      user_id = int(user_id_str)
    except ValueError:
      # Handle invalid user ID format (return 400 Bad Request)
      self.send_error(400, "Invalid user ID format")
      return

    # Simulate retrieving ranks based on user ID (replace with your logic)
    ranks = [-1, 15, 16]

    # Create RankResponseBody object
    # Create a dictionary from RankResponseBody object
    response_data = {"ranks": ranks}

    # Encode the response body as JSON
    json_data = json.dumps(response_data)

    # Set response headers
    self.send_response(200)
    self.send_header("Content-type", "application/json")
    self.end_headers()

    # Write the JSON data to the response
    self.wfile.write(json_data.encode())

# Server configuration
PORT = 8082

with HTTPServer(("", PORT), RankRequestHandler) as httpd:
  print(f"Serving Rank API on port {PORT}")
  httpd.serve_forever()

