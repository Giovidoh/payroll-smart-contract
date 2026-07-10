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

This project is part of my ongoing Web3 developer portfolio, and also serves as the basis for my bachelor's thesis.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Built With

- [![Solidity][Solidity]][Solidity-url]
- [Foundry][Foundry-url]
- [OpenZeppelin Contracts](https://www.openzeppelin.com/contracts)

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
- View all registered employees — `getAllEmployees()`
- View the total salaries currently owed — `getTotalSalaries()`
- Check if an address is a registered employee — `getEmployeeExistence(address employeeAddress)`

Fund management (`deposit`, `withdraw`), payroll execution (`runPayroll`), and an employee-facing salary getter are actively being developed — see the Roadmap below.

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

- `test/unit/` — tests each function in isolation. Currently covers employee management (`addEmployee`, `removeEmployee`) with 18 tests, including revert conditions, state changes, event emissions, access control, and boundary cases such as removing the first, middle, last, and only employee in the array.
- `test/integration/` — will cover multiple functions working together end-to-end (e.g. deposit → run payroll → verify payments), once fund management and payroll execution are implemented.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- ROADMAP -->

## Roadmap

- [x] Employee management — `addEmployee`, `removeEmployee` (gas-efficient array + mapping storage, swap-and-pop removal)
- [x] Unit tests for employee management — 18 tests, full framework coverage (reverts, state changes, events, access control, boundaries)
- [x] `updateSalary` — update an existing employee's salary and/or address
- [ ] Fund management — `deposit`, `withdraw` (ERC-20 stablecoin)
- [ ] Payroll execution — `runPayroll`
- [ ] Employee-facing getter — `getEmployee()`, viewable by the owner and the employee themselves
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
