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
- **`runPayroll()` scales linearly with employee count (O(n)).** Every employee paid in a single run adds real gas cost, since each payment is an individual token transfer. At a large enough employee count, a single `runPayroll()` call could theoretically exceed a block's gas limit. This is a known, documented limitation for this project's scope. Production systems at scale typically solve this by having each employee individually claim their own accrued salary instead of the employer pushing payment to everyone in one transaction — turning one large O(n) transaction into many small O(1) ones.
- **No explicit reentrancy guard, by design.** Every state-changing function (`addEmployee`, `removeEmployee`, `updateSalary`, `deposit`, `withdraw`, `runPayroll`) is restricted to the contract owner. Since employees are never the owner, even a malicious employee contract attempting to re-enter during its own payment inside `runPayroll()` would be blocked by access control on every function it could call back into.

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

Deployment instructions (local + testnet) will be added once the contract is ready to deploy.

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
- Pay every registered employee their salary in a single transaction — `runPayroll()`

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

- `test/unit/` — tests each function in isolation. Currently covers employee management (`addEmployee`, `removeEmployee`, `updateSalary`, `getEmployee`) and fund management (`deposit`, `withdraw`), including revert conditions, state changes, event emissions, access control, and boundary cases (e.g. removing the first/middle/last/only employee in the array, withdrawing exactly at the payroll reserve boundary).
- `test/integration/` — will cover multiple functions working together end-to-end (e.g. deposit → run payroll → verify payments), once `runPayroll()` is tested.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- ROADMAP -->

## Roadmap

- [x] Employee management — `addEmployee`, `removeEmployee` (gas-efficient array + mapping storage, swap-and-pop removal)
- [x] Unit tests for employee management — 18 tests, full framework coverage (reverts, state changes, events, access control, boundaries)
- [x] `updateSalary` — update an existing employee's salary
- [x] `getEmployee` — viewable by the owner and the employee themselves
- [x] Fund management — `deposit`, `withdraw` (ERC-20 stablecoin), with a payroll reserve protecting a fixed number of future payroll cycles from withdrawal
- [x] `runPayroll` — implemented, tests in progress
- [ ] Integration test suite
- [ ] Deployment to Sepolia testnet

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
