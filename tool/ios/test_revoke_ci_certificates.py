import unittest

import revoke_ci_certificates as r


def cert(cid, ctype, name):
    return {"id": cid, "attributes": {"certificateType": ctype, "displayName": name,
                                      "name": f"{ctype}: {name}"}}


class RevokeTest(unittest.TestCase):
    def test_only_ci_development_certificates(self):
        certs = [
            cert("1", "DEVELOPMENT", "Created via API"),
            cert("2", "IOS_DEVELOPMENT", "Created via API"),
            cert("3", "DEVELOPMENT", "Jane's MacBook"),
            cert("4", "DISTRIBUTION", "Created via API"),
        ]
        self.assertEqual([c["id"] for c in r.ci_certificates(certs)], ["1", "2"])

    def test_missing_key_revokes_nothing(self):
        import os
        for k in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH"):
            os.environ.pop(k, None)
        self.assertEqual(r.main(), 0)


if __name__ == "__main__":
    unittest.main()
