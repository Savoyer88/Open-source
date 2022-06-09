#!/usr/bin/env python
# coding=utf-8

import unittest

import main


class TestCase(unittest.TestCase):

    def setUp(self):
        self.app = main.app.test_client()

    def test_main_page(self):
        response = self.app.get('/', follow_redirects=True)
        self.assertEqual(response.status_code, 200)

    def test_users_page(self):
        response = self.app.get('/users', follow_redirects=True)
        self.assertEqual(response.status_code, 200)
#adding an additional unit test to check the value
    def test_singleuser_page(self):
        response = self.app.get('/users/lara_croft', follow_redirects=True)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["name"],"Lara Croft")

if __name__ == '__main__':
    unittest.main()
