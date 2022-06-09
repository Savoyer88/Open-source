resource "aws_cloudwatch_dashboard" "dashboard-terraform" {
  dashboard_name = "cloudwatch-dashboard"

  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          [
            "CWAgent",
            "disk_used_percent",
            "InstanceId",
            "ami-005de95e8ff495156",
            "path",
             "/",
            "device",
            "xvda1",
            "fstype",
            "xfs"
          ]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "stacked": true,
        "title": "EC2 Instance Disk Used"
      }
    }
    
    
  ]
}
EOF

}

resource "aws_cloudwatch_metric_alarm" "bell" {
  alarm_name                = "bell"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "Disk usage"
  namespace                 = "AWS/EC2"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "50"
  alarm_description         = "This metric monitors node disk usage"
  insufficient_data_actions = []
}
