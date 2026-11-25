"""Unit tests for the CN Busters Python REST backend."""
import json
import threading
import unittest
import urllib.error
import urllib.request

from backend.server import CATALOG_ETAG, create_server


class BackendServerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = create_server("127.0.0.1", 0, "A")
        cls.port = cls.server.server_address[1]
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f"http://127.0.0.1:{cls.port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def test_root_html_and_no_store(self):
        with urllib.request.urlopen(f"{self.base}/") as resp:
            self.assertEqual(resp.status, 200)
            self.assertEqual(resp.headers["X-Backend"], "A")
            self.assertEqual(resp.headers["Cache-Control"], "no-store")
            body = resp.read().decode()
            self.assertIn("Served by Backend A", body)

    def test_status_json_and_forwarded_headers(self):
        req = urllib.request.Request(
            f"{self.base}/api/status",
            headers={
                "X-Forwarded-For": "192.168.1.14",
                "X-Forwarded-Proto": "https",
            },
        )
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 200)
            self.assertEqual(resp.headers["X-Backend"], "A")
            self.assertEqual(resp.headers["Cache-Control"], "no-store")
            payload = json.loads(resp.read().decode())
            self.assertEqual(payload["backend"], "A")
            self.assertEqual(payload["status"], "ok")
            self.assertEqual(payload["x_forwarded_for"], "192.168.1.14")
            self.assertEqual(payload["x_forwarded_proto"], "https")

    def test_catalog_etag_and_conditional_304(self):
        with urllib.request.urlopen(f"{self.base}/api/catalog") as resp:
            self.assertEqual(resp.status, 200)
            self.assertEqual(resp.headers["ETag"], CATALOG_ETAG)
            self.assertIn("max-age=60", resp.headers["Cache-Control"])

        req = urllib.request.Request(
            f"{self.base}/api/catalog",
            headers={"If-None-Match": CATALOG_ETAG},
        )
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(req)
        self.assertEqual(ctx.exception.code, 304)
        self.assertEqual(ctx.exception.headers["X-Backend"], "A")

    def test_health_and_head_and_404(self):
        with urllib.request.urlopen(f"{self.base}/health") as resp:
            self.assertEqual(resp.status, 200)
            self.assertEqual(resp.read(), b"ok\n")

        head_req = urllib.request.Request(f"{self.base}/api/catalog", method="HEAD")
        with urllib.request.urlopen(head_req) as resp:
            self.assertEqual(resp.status, 200)
            self.assertEqual(resp.headers["ETag"], CATALOG_ETAG)
            self.assertEqual(resp.read(), b"")

        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(f"{self.base}/does-not-exist")
        self.assertEqual(ctx.exception.code, 404)

    def test_metrics_endpoint_counts_requests(self):
        with urllib.request.urlopen(f"{self.base}/api/metrics") as resp:
            self.assertEqual(resp.status, 200)
            self.assertEqual(resp.headers["Cache-Control"], "no-store")
            before = json.loads(resp.read().decode())

        req_304 = urllib.request.Request(
            f"{self.base}/api/catalog",
            headers={"If-None-Match": CATALOG_ETAG},
        )
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(req_304)
        self.assertEqual(ctx.exception.code, 304)

        with urllib.request.urlopen(f"{self.base}/api/metrics") as resp:
            after = json.loads(resp.read().decode())

        self.assertEqual(after["backend"], "A")
        self.assertGreaterEqual(after["requests_total"], before["requests_total"] + 2)
        self.assertGreaterEqual(after["cache_hits_304"], before["cache_hits_304"] + 1)


if __name__ == "__main__":
    unittest.main()
