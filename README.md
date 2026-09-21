<!-- Improved compatibility of back to top link: See: https://github.com/othneildrew/Best-README-Template/pull/73 -->

<a id="readme-top"></a>

<!-- PROJECT SHIELDS -->

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![project_license][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]

<!-- PROJECT LOGO -->
<br />
<div align="center">

<h3 align="center">Payroll Smart Contract</h3>

  <p align="center">
    An on-chain payroll system that lets an employer pay employees in a stablecoin, instantly and verifiably on Ethereum.
    <br />
    <a href="https://github.com/Giovidoh/payroll-smart-contract"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/Giovidoh/payroll-smart-contract/issues/new?labels=bug&template=bug-report---.md">Report Bug</a>
    &middot;
    <a href="https://github.com/Giovidoh/payroll-smart-contract/issues/new?labels=enhancement&template=feature-request---.md">Request Feature</a>
  </p>
</div>

<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
        <li><a href="#architecture-notes">Architecture Notes</a></li>
        <li><a href="#known-limitations--future-improvements">Known Limitations & Future Improvements</a></li>
        <li><a href="#live-sepolia-deployments">Live Sepolia Deployments</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#testing">Testing</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>

<!-- ABOUT THE PROJECT -->

## About The Project

**Payroll Smart Contract** is a Solidity project exploring how blockchain can be used to manage and execute payroll on-chain. An employer can register employees, fund the contract with a stablecoin, and trigger salary payments to every employee in a single transaction — with every action recorded on-chain and independently verifiable by anyone.

A key design decision: the contract enforces a **payroll reserve**. When deployed, the employer sets a fixed number of payroll cycles (`i_reservedPayrollCycles`) that must always remain available in the contract before any surplus can be withdrawn. This value is immutable, set once at deployment and never changeable afterward — so the employer can never quietly drain funds that employees are relying on. This reserve specifically restricts _discretionary withdrawal_ by the owner — it does not block `runPayroll()` itself, which only requires enough balance to cover the current cycle. Otherwise, funds meant to guarantee future payroll could end up frozen, satisfying neither the reserve's purpose nor the current cycle's obligations.

This project is part of my ongoing Web3 developer portfolio, and also serves as the basis for my bachelor's thesis.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Built With

- [![Solidity][Solidity]][Solidity-url]
- [Foundry][Foundry-url]
- [OpenZeppelin Contracts](https://www.openzeppelin.com/contracts)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Architecture Notes

- **No off-chain backend or database.** Payment history isn't stored in contract state — every payroll run emits a `SalaryPaid` event per employee. Anyone (a frontend, a block explorer, an off-chain indexer) can reconstruct full payment history by reading past events, without the contract needing to maintain redundant storage.
- **`runPayroll()` scales linearly with employee count (O(n)) — measured, not assumed.** Every employee paid in a single run adds real gas cost, since each payment is an individual token transfer. `test/gas/PayrollGasScaling.t.sol` measures this directly (`make gas-scaling`), deploying a fresh contract per headcount and cooling the contract, the token and every recipient before each call so the numbers match a real cold transaction, intrinsic 21,000 gas included. The cost is strictly linear:

  | | gas cost | per-employee marginal cost |
  |---|---|---|
  | Steady state | `39,533 + 16,043 × n` | 16,043 |
  | First cycle | `39,533 + 33,143 × n` | 33,143 |

  The 17,100 gap per employee is exactly the zero-to-nonzero `SSTORE` premium (20,000 instead of 2,900) paid once per storage slot. Validated against the network: the model predicts 71,619 gas for two employees in steady state, and the real Sepolia transaction [`0x2bca7683…`](https://sepolia.etherscan.io/tx/0x2bca7683da1fb69baf2f9eb8f6eeaece18c3d8e3cb96819ce7049647e8a1621d) consumed 73,842 — a 3% gap. Against a 30M block gas limit, that puts the ceiling at roughly **1,867 employees per run in steady state, 903 on the first cycle**. Note that the figure to quote is the slope (16,043), not the average at a given headcount — at n=2 the average is 36,921, which inflates the marginal cost by 130% by burying the fixed cost inside it. This is also a gas-cost tradeoff, not just a scalability one: in this push model, whoever calls `runPayroll()` pays gas for every employee's payment in one transaction. A pull/claim-based model, where each employee withdraws their own accrued salary individually, would distribute both the gas cost and the block-size risk across every employee's own transaction instead of concentrating it entirely on one caller. This is a known, documented limitation for this project's scope. Production systems at scale (Sablier, Superfluid) typically use the pull model for exactly this reason.
- **Ownership uses a two-step transfer (`Ownable2Step`).** A single accidental `transferOwnership()` call to a wrong or unreachable address cannot lock the contract, since the new address must explicitly call `acceptOwnership()` before control actually changes hands. This does not protect against permanent loss of the current owner's private key — see Known Limitations below.
- **`runPayroll()` is intentionally permissionless, gated by a minimum interval instead of `onlyOwner`.** Anyone can call it, but only once every `i_payrollInterval` seconds since the last successful run, tracked via `s_lastPayrollTimestamp`. This prevents an owner from indefinitely withholding payment by simply never calling the function, while the interval guard prevents the same cycle from being paid twice. `s_lastPayrollTimestamp` is updated **before** the payment loop executes (Checks-Effects-Interactions) — this is what provides reentrancy protection for this specific function, since it's the one function in the contract not restricted by `onlyOwner`. Every other state-changing function remains owner-gated, which structurally blocks reentrancy there, since no employee address is ever the owner.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Known Limitations & Future Improvements

This section documents deliberate scope decisions and known tradeoffs, kept here intentionally rather than hidden — useful both as an honest engineering record and as supporting material for the accompanying thesis.

- **Single-key owner is a point of failure.** `Ownable2Step` protects against an accidental transfer to the wrong address, but not against permanent loss of the current owner's private key. For real deployment, the owner address should be a multisig (e.g. a Gnosis Safe) rather than a single personal wallet — a code-level fix (`Ownable2Step`) does not replace an operational one (key custody practice).
- **The owner can bypass the payroll reserve by self-registering as an employee.** Since `runPayroll()` pays out based solely on the current employee list and `s_totalSalaries`, without distinguishing legitimate employees from the owner themselves, an owner could add their own address as an "employee" and extract funds via `runPayroll()` that `withdraw()`'s reserve check would otherwise have blocked. This is not unique to smart contracts — any single administrator with full control over both the employee list and payment execution can create "ghost employees" in a traditional payroll system too. Proper mitigation requires separation of duties: a multisig owner, a timelock on employee list changes, or splitting "who can manage employees" from "who can trigger payment" into distinct roles. Out of scope for the current version; the clearest next step for hardening this contract.
- **No salary proration for employees added mid-cycle.** An employee added at any point before `runPayroll()` executes receives their full salary for that cycle — the contract does not track how much of the cycle they were actually registered for. This is a deliberate simplification: proration would require storing a `joinedTimestamp` per employee and calculating a partial amount per person during payroll execution, a real feature addition rather than a quick fix. Full salary regardless of join timing was chosen for this version; proration is a natural v2 candidate.
- **`payrollInterval` is a fixed duration in seconds, not calendar-aware.** A "monthly" interval is implemented as a flat 30-day duration (`2,592,000` seconds), not an actual calendar month. Since real months vary from 28 to 31 days, a contract run consistently on a 30-day interval will slowly drift relative to a real calendar's 1st-of-the-month over time. Calendar-aware scheduling would require off-chain coordination or a more complex on-chain date library, out of scope here.
- **Missed payroll cycles are not paid retroactively.** If `runPayroll()` isn't called for longer than one interval — say, 60 days pass instead of 30 — the next successful call pays out exactly one cycle's worth, then resets `s_lastPayrollTimestamp` to the current time. The cycle that was skipped in between is never paid; that pay simply disappears rather than accumulating. A correct fix would track how many full intervals have elapsed, pay `salary × cyclesElapsed` per employee, and advance `s_lastPayrollTimestamp` by whole intervals (not to `block.timestamp`) to keep the schedule anchored rather than drifting forward every time a call is late. This wasn't built because it compounds two other documented limitations rather than existing in isolation: without proration, an employee added right before a large catch-up run would receive multiple cycles of pay for a fraction of the time worked, and the ghost-employee reserve bypass above becomes more severe if an owner can trigger one large catch-up payment instead of many small ones. Solving this properly means addressing it alongside proration and reserve enforcement, not as a standalone patch.
- **Interval guard requires waiting the full interval on a live network.** Unlike local Foundry tests, which can warp time instantly with `vm.warp`, a real deployment has no such shortcut — `runPayroll()` genuinely cannot be called until real time has passed. See Live Sepolia Deployments below for a separate demo deployment with a shortened interval, used specifically to demonstrate the full payroll cycle without a month-long wait.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Live Sepolia Deployments

**Production configuration** (30-day interval, 3 reserved cycles — realistic values for actual use):

- Payroll: [`0xA15fBb6884b64A93B453628abd9b181D434D206A`](https://sepolia.etherscan.io/address/0xA15fBb6884b64A93B453628abd9b181D434D206A)
- MockUSDC: [`0x44a0E5caF4a097583a9384c8Ef78403Ee2a2C1bc`](https://sepolia.etherscan.io/address/0x44a0E5caF4a097583a9384c8Ef78403Ee2a2C1bc)

**Demo configuration** (10-second interval — exists purely so the full payroll cycle, including the interval guard, can be tested and demonstrated end-to-end without a real month-long wait):

- Payroll: [`0x68B5Fc5B4B57dFBEE5d295BA25da36790aA68340`](https://sepolia.etherscan.io/address/0x68B5Fc5B4B57dFBEE5d295BA25da36790aA68340)
- MockUSDC: [`0x6d8a78Bc479cF9C891b2417EC08c6C885e1713cB`](https://sepolia.etherscan.io/address/0x6d8a78Bc479cF9C891b2417EC08c6C885e1713cB)

Both are real deployments on Sepolia, not simulations — every transaction is publicly verifiable. A full payroll cycle was executed end-to-end against the demo deployment on 2026-09-21: the contract was funded, two employees were registered, and `runPayroll()` paid both of them in a single transaction ([`0x2bca7683…`](https://sepolia.etherscan.io/tx/0x2bca7683da1fb69baf2f9eb8f6eeaece18c3d8e3cb96819ce7049647e8a1621d), 73,842 gas).

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- GETTING STARTED -->

## Getting Started

### Prerequisites

- [git](https://git-scm.com/)
- [foundry](https://getfoundry.sh/)

### Installation

1. Clone the repo

```sh
   git clone https://github.com/Giovidoh/payroll-smart-contract.git
   cd payroll-smart-contract
```

2. Install dependencies

```sh
   forge install
```

3. Build the project

```sh
   forge build
```

4. Run the test suite

```sh
   forge test
```

### Deployment

```sh
make install       # install dependencies
make deploy-anvil   # deploy locally
make deploy-sepolia  # deploy to Sepolia (requires SEPOLIA_RPC_URL and ETHERSCAN_API_KEY in .env)
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- USAGE EXAMPLES -->

## Usage

The contract owner (the employer) can currently:

- Add a new employee — `addEmployee(address employeeAddress, uint256 salary)`
- Remove an existing employee — `removeEmployee(address employeeAddress)`
- Update an existing employee's salary — `updateSalary(address employeeAddress, uint256 newSalary)`
- View all registered employees — `getAllEmployees()`
- View the total salaries currently owed — `getTotalSalaries()`
- Check if an address is a registered employee — `getEmployeeExistence(address employeeAddress)`
- Deposit stablecoin funds into the contract — `deposit(uint256 amount)` (requires an `approve()` on the stablecoin beforehand)
- Withdraw surplus funds, above the required payroll reserve — `withdraw(uint256 amount)`
- Check how much is currently available for withdrawal — `getAvailableAmountForWithdrawal()`
- Transfer ownership safely via a two-step process — `transferOwnership(address)` followed by the new owner's own `acceptOwnership()` call

**Anyone** can:

- Trigger a payroll run — `runPayroll()` — once every `i_payrollInterval` seconds since the last successful run. Pays every registered employee their salary in a single transaction.

The owner and the concerned employee themselves can:

- View a specific employee's data — `getEmployee(address employeeAddress)`

Payment history is available via emitted events (`SalaryPaid`, `PayrollCompleted`) rather than a dedicated getter — see Architecture Notes above.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- TESTING -->

## Testing

### Run all tests

```sh
forge test
```

### Run tests with verbosity

```sh
forge test -vvv
```

### Check test coverage

```sh
forge coverage
```

Tests are organized by scope:

- `test/unit/` — tests each function in isolation, including its dependencies where necessary (e.g. `deposit`/`withdraw` calling into the mock stablecoin). Covers employee management (`addEmployee`, `removeEmployee`, `updateSalary`, `getEmployee`), fund management (`deposit`, `withdraw`), payroll execution (`runPayroll`, including the interval guard), and ownership transfer (`Ownable2Step`) — reverts, state changes, event emissions, access control, and boundary cases throughout.
- `test/integration/` — verifies multiple functions working together across a realistic sequence: adding employees, funding the contract, running payroll, updating salaries mid-cycle, removing and adding employees, running payroll again, and withdrawing surplus — with every balance independently checked against hand-calculated expected values at each step.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- ROADMAP -->

## Roadmap

- [x] Employee management — `addEmployee`, `removeEmployee` (gas-efficient array + mapping storage, swap-and-pop removal)
- [x] Unit tests for employee management — 18 tests, full framework coverage (reverts, state changes, events, access control, boundaries)
- [x] `updateSalary` — update an existing employee's salary
- [x] `getEmployee` — viewable by the owner and the employee themselves
- [x] Fund management — `deposit`, `withdraw` (ERC-20 stablecoin), with a payroll reserve protecting a fixed number of future payroll cycles from withdrawal
- [x] `runPayroll` — implemented and fully tested
- [x] Integration test suite — full lifecycle scenario, hand-verified
- [x] Two-step ownership transfer (`Ownable2Step`) — 4 tests, including proof that acceptance is required and the old owner genuinely loses access
- [x] Payroll interval guard — `runPayroll()` is permissionless, gated by a minimum interval since the last run
- [x] Deployment to Sepolia testnet — production and demo configurations, both verified
- [ ] Catch-up payment logic for missed cycles — see Known Limitations
- [ ] Salary proration for employees added mid-cycle

See the [open issues](https://github.com/Giovidoh/payroll-smart-contract/issues) for a full list of proposed features and known issues.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTRIBUTING -->

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- LICENSE -->

## License

Distributed under the MIT License. See `LICENSE.txt` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- CONTACT -->

## Contact

Giovanni - [GitHub](https://github.com/Giovidoh) - [@ICG_reborns](https://x.com/ICG_reborns) - giovidoh@gmail.com

Project Link: [https://github.com/Giovidoh/payroll-smart-contract](https://github.com/Giovidoh/payroll-smart-contract)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- ACKNOWLEDGMENTS -->

## Acknowledgments

- [Cyfrin Updraft](https://updraft.cyfrin.io/) — Solidity & Foundry fundamentals
- [OpenZeppelin Contracts](https://www.openzeppelin.com/contracts)
- [Best-README-Template](https://github.com/othneildrew/Best-README-Template)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->

[contributors-shield]: https://img.shields.io/github/contributors/Giovidoh/payroll-smart-contract.svg?style=for-the-badge
[contributors-url]: https://github.com/Giovidoh/payroll-smart-contract/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/Giovidoh/payroll-smart-contract.svg?style=for-the-badge
[forks-url]: https://github.com/Giovidoh/payroll-smart-contract/network/members
[stars-shield]: https://img.shields.io/github/stars/Giovidoh/payroll-smart-contract.svg?style=for-the-badge
[stars-url]: https://github.com/Giovidoh/payroll-smart-contract/stargazers
[issues-shield]: https://img.shields.io/github/issues/Giovidoh/payroll-smart-contract.svg?style=for-the-badge
[issues-url]: https://github.com/Giovidoh/payroll-smart-contract/issues
[license-shield]: https://img.shields.io/github/license/Giovidoh/payroll-smart-contract.svg?style=for-the-badge
[license-url]: https://github.com/Giovidoh/payroll-smart-contract/blob/master/LICENSE.txt
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://www.linkedin.com/in/cir-giovanni-idoh-277435379/
[Solidity]: https://img.shields.io/badge/Solidity-%23363636.svg?style=for-the-badge&logo=solidity&logoColor=white
[Solidity-url]: https://www.soliditylang.org/
[Foundry-url]: https://www.getfoundry.sh/introduction/getting-started
