// A $5 monthly budget on the resource group: an email at 80% and at 100%.
// The free plan costs nothing; this is the alarm if that ever changes.
// Deployed once by setup.sh, so the address never goes through GitHub.
param email string
param startDate string           // the first of this month, yyyy-MM-01
param amount int = 5

resource budget 'Microsoft.Consumption/budgets@2023-05-01' = {
  name: 'pickleball-web-budget'
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: { startDate: startDate }
    notifications: {
      at80: { enabled: true, operator: 'GreaterThanOrEqualTo', threshold: 80, contactEmails: [ email ], thresholdType: 'Actual' }
      at100: { enabled: true, operator: 'GreaterThanOrEqualTo', threshold: 100, contactEmails: [ email ], thresholdType: 'Forecasted' }
    }
  }
}
