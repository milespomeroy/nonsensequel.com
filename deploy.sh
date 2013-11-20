#!/bin/bash
# Deploy nonsensequel.com to S3

hugo
cd public
aws s3 sync . s3://www.nonsensequel.com
cd ..
