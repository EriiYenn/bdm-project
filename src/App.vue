<template>
	<h1 style="font-weight: bold">BDM Project</h1>
	<br />

	<header>
		<!-- <img alt="Vue logo" class="logo" src="./assets/logo.svg" width="125" height="125" /> -->
		<div class="projects-grid">
			<div
				v-if="projects.length > 0"
				v-for="project in projects"
				:key="project.title"
				:class="
					project.claimed
						? 'project-claimed'
						: project.raised >= project.goal
						? 'project-success'
						: new Date() < project.starting
						? 'project-not-started'
						: new Date() < project.deadline
						? 'project-running'
						: 'project-fail'
				"
			>
				<h3 style="text-align: center">{{ project.title }}</h3>
				<p style="text-align: center">{{ project.description }}</p>
				<hr />
				<div style="padding-left: 16px">
					<h3>
						To reach
						<img
							src="https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Ethereum-icon-purple.svg/2048px-Ethereum-icon-purple.svg.png"
							width="16"
						/>{{ project.goal }}
					</h3>
					<p>Starting: {{ project.starting.toLocaleString() }}</p>
					<p>Deadline: {{ project.deadline.toLocaleString() }}</p>
					<p>
						Raised:
						<img
							src="https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Ethereum-icon-purple.svg/2048px-Ethereum-icon-purple.svg.png"
							width="16"
						/>{{ project.raised }}
					</p>
				</div>
				<hr />
				<p style="font-size: small; text-align: center">By: {{ project.owner }}</p>
				<br />
				<div style="text-align: center">
					<div v-if="project.owner !== userAddress">
						Fund:
						<input
							type="number"
							v-model="pledgeValue"
							placeholder="How much do you want to pledge?"
							:disabled="
								new Date() < project.starting ||
								new Date() > project.deadline ||
								project.owner === userAddress
							"
						/><br /><br />
					</div>
					<button
						@click="pledge(project.id)"
						v-if="project.owner !== userAddress || new Date() < project.deadline"
						:disabled="
							new Date() < project.starting ||
							new Date() > project.deadline ||
							project.owner === userAddress
						"
					>
						Pledge
					</button>
					<button
						@click="claim(project.id)"
						:disabled="new Date() < project.deadline || project.raised < project.goal || project.claimed"
						v-if="project.owner === userAddress"
						style="margin-left: 8px"
					>
						Claim
					</button>
					<button
						@click="refund(project.id)"
						:disabled="
							new Date() < project.deadline ||
							project.claimed ||
							project.raised >= project.goal ||
							project.raised === 0
						"
						v-if="
							project.owner !== userAddress ||
							(new Date() > project.deadline && !project.claimed && project.raised < project.goal)
						"
						style="margin-left: 8px"
					>
						Refund
					</button>
				</div>
			</div>
			<div v-else class="projects-empty-grid">
				<h2>No projects yet!</h2>
			</div>
		</div>
	</header>

	<main>
		<h4>Adress: {{ userAddress }}</h4>
		<br />
		<h4>
			Balance:
			<img
				src="https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Ethereum-icon-purple.svg/2048px-Ethereum-icon-purple.svg.png"
				width="16"
			/>{{ userBalance }}
		</h4>
		<br />
		<button @click="login">Login</button>
		&nbsp;&nbsp;
		<button @click="showMyProjects">My Projects</button>
		<br /><br /><br />
		<button @click="showOpenProjects">Open Projects</button>
		&nbsp;&nbsp;
		<button @click="showInvestedProjects">Invested Projects</button>
		<br /><br />
		<button @click="showFailedProjects">Failed Projects</button>
		&nbsp;&nbsp;
		<button @click="showNewestProjects">Newest Projects</button>
		<br /><br />
		Select owner: <input type="text" v-model="pickedOwner" placeholder="Select specific owner..." />
		<br />
		<button @click="showSpecificProjects">Owner Projects</button>
		<br /><br /><br />
		Project Title: <input type="text" v-model="projectName" placeholder="Pick a good name!" /><br />
		Project Description:
		<input type="text" v-model="projectDescription" placeholder="Let people know what you do..." /><br />
		Project Goal: <input type="number" v-model="projectGoal" placeholder="How much do you need?" /><br />
		Project Start Date: <input type="datetime-local" v-model="projectStartDate" /><br />
		Project Deadline:<input type="datetime-local" v-model="projectDeadline" /><br /><br />
		<button @click="launchProject">Lets launch it!</button>
	</main>
</template>

<script lang="ts">
import { defineComponent, ref } from "vue";
import { Contract, ethers } from "ethers";
import { CrowdfundingPlatform } from "../typechain-types/CrowdfundingPlatform";
import contractAddress from "../contract.json";
import contractABI from "../artifacts/contracts/CrowdfundingPlatform.sol/CrowdfundingPlatform.json";

export default defineComponent({
	mounted() {
		this.login();
	},
	setup() {
		interface Project {
			id: number;
			owner: string;
			title: string;
			description: string;
			goal: number;
			starting: Date;
			deadline: Date;
			raised: number;
			claimed: boolean;
		}

		const userAddress = ref("");
		const userBalance = ref("");
		const pledgeValue = ref(0);
		const pickedOwner = ref("");

		const projects = ref<Array<Project>>([]);

		const projectName = ref("");
		const projectDescription = ref("");
		const projectGoal = ref(0); // in ETH
		const projectStartDate = ref("");
		const projectDeadline = ref("");

		let provider: ethers.providers.Web3Provider | null = null;
		let user: ethers.providers.JsonRpcSigner | null = null;
		let contract: CrowdfundingPlatform | null = null;

		const initContract = () => {
			if (!user) return;

			contract = new Contract(contractAddress.address, contractABI.abi, user) as CrowdfundingPlatform;

			contract.on("Claim", async (_projectID: number) => {
				projects.value = projects.value.map((project) => {
					if (project.id == _projectID) {
						project.claimed = true;
						console.log("Claimed project " + project.title);
					}
					return project;
				});

				processUser();
			});

			contract.on("Pledge", async (_projectID: number, _: string, amount: ethers.BigNumberish) => {
				projects.value = projects.value.map((project) => {
					if (project.id == _projectID) {
						project.raised += parseFloat(ethers.utils.formatEther(amount));
						console.log("Pledged " + amount + " ETH to project " + project.title);
					}
					return project;
				});

				processUser();
			});

			contract.on("Refund", async (_projectID: number, _: string, amount: ethers.BigNumberish) => {
				projects.value = projects.value.map((project) => {
					if (project.id == _projectID) {
						project.raised -= parseFloat(ethers.utils.formatEther(amount));
					}
					return project;
				});

				processUser();
			});

			showOpenProjects();
		};

		const showOpenProjects = async () => {
			await loadAllProjects();

			projects.value = projects.value.filter((project) => project.deadline > new Date());
		};

		const showMyProjects = async () => {
			await loadAllProjects();

			projects.value = projects.value.filter((project) => project.owner == userAddress.value);
		};

		const showFailedProjects = async () => {
			await loadAllProjects();

			projects.value = projects.value.filter(
				(project) => new Date() > project.deadline && project.raised < project.goal
			);
		};

		const showNewestProjects = async () => {
			await loadAllProjects();

			projects.value = projects.value.sort((a, b) => b.starting.getTime() - a.starting.getTime());
			// await showOpenProjects(); // Show only open projects for the newest?
		};

		const showSpecificProjects = async () => {
			await loadAllProjects();

			projects.value = projects.value.filter((project) => project.owner == pickedOwner.value);
		};

		const showInvestedProjects = async () => {
			if (!contract) return;

			await loadAllProjects();

			let investedProjects: Array<number> = [];

			for (let i = 0; i < projects.value.length; i++) {
				const project = projects.value[i];

				const isInvested = await contract.contributions(project.id, userAddress.value);

				if (parseInt(ethers.utils.formatEther(isInvested).toString()) > 0) investedProjects.push(i);
			}

			projects.value = projects.value.filter((project) => project.id in investedProjects);
		};

		const loadAllProjects = async () => {
			if (!contract) return;

			const projectsCount = parseInt(ethers.utils.formatUnits(await contract.projectsCount(), "wei"));
			projects.value = [];

			for (let i = 0; i < projectsCount; i++) {
				const project = await contract.projects(i);

				projects.value.push({
					id: i,
					owner: project.projectCreator,
					title: project.projectName,
					description: project.projectDescription,
					goal: parseFloat(ethers.utils.formatEther(project.goal)),
					starting: new Date(parseInt(project.started.toString() + "000")),
					deadline: new Date(parseInt(project.deadline.toString() + "000")),
					raised: parseFloat(ethers.utils.formatEther(project.amountRaised)),
					claimed: project.isClaimed,
				});
			}

			console.log(projects.value);
			console.log("Projects count: " + projectsCount);
		};

		const launchProject = async () => {
			if (!contract) return;

			// console.log(projectName.value);
			// console.log(projectDescription.value);
			// console.log(
			// 	parseInt(ethers.utils.formatEther(ethers.utils.parseEther((projectGoal.value * 10 ** 18).toString()))) /
			// 		10 ** 18
			// );
			// console.log(parseInt((new Date(projectStartDate.value.toString()).getTime() / 1000).toFixed(0)).toString());
			// console.log(parseInt((new Date(projectDeadline.value.toString()).getTime() / 1000).toFixed(0)).toString());

			try {
				const tx = await contract.launch(
					projectName.value,
					projectDescription.value,
					ethers.utils.parseEther(projectGoal.value.toString()),
					parseInt((new Date(projectStartDate.value.toString()).getTime() / 1000).toFixed(0)).toString(),
					parseInt((new Date(projectDeadline.value.toString()).getTime() / 1000).toFixed(0)).toString()
				);

				await tx.wait();

				console.log("Project " + projectName.value + " launched!");

				await showOpenProjects();
			} catch (e: any) {
				if (e.message.includes("Nonce"))
					alert("Nonce is too high!! Clear Metamask activity data & nonce in Advanced settings");
			}
		};

		const pledge = async (projectIndex: number) => {
			if (!contract) return;

			try {
				const tx = await contract.pledge(projectIndex, {
					value: ethers.utils.parseEther(pledgeValue.value.toString()),
				});

				await tx.wait();
			} catch (e: any) {
				if (e.code === -32603)
					alert("Nonce is too high!! Clear Metamask activity data & nonce in Advanced settings");
			}
		};

		const claim = async (projectIndex: number) => {
			if (!contract) return;

			try {
				const tx = await contract.claim(projectIndex);

				await tx.wait();
				await showOpenProjects();
			} catch (e: any) {
				if (e.message.includes("Project has not reached its goal"))
					alert("Project has not reached its goal :(");
			}
		};

		const refund = async (projectIndex: number) => {
			if (!contract) return;

			try {
				const tx = await contract.refund(projectIndex);

				await tx.wait();
			} catch (e: any) {
				if (e.message.includes("Project has reached its goal")) alert("Project has reached its goal");
				else if (e.message.includes("Project has not ended yet")) alert("Project has not ended yet");
				else if (e.message.includes("You have not contributed to this project"))
					alert("You have not contributed to this project");
			}
		};

		const login = async () => {
			if (!("ethereum" in window)) {
				alert("Please install MetaMask first.");
				return;
			}
			(window as any).ethereum.enable();

			try {
				provider = new ethers.providers.Web3Provider((window as any).ethereum);
				user = provider.getSigner();

				initContract();

				await processUser();

				(window as any).ethereum.on("accountsChanged", function () {
					processUser();
				});
			} catch (e) {
				alert(e);
			}
		};

		const processUser = async () => {
			if (!user) return;

			userAddress.value = await user.getAddress();
			userBalance.value = ethers.utils.formatEther(await user.getBalance());
		};

		return {
			userAddress,
			userBalance,
			login,
			projects,
			projectName,
			projectDescription,
			projectGoal,
			projectStartDate,
			projectDeadline,
			launchProject,
			showOpenProjects,
			pledgeValue,
			pledge,
			claim,
			showInvestedProjects,
			showFailedProjects,
			showNewestProjects,
			showSpecificProjects,
			pickedOwner,
			showMyProjects,
			refund,
		};
	},
});
</script>

<style scoped>
.projects-grid {
	display: grid;
	grid-template-columns: repeat(4, 1fr);
	grid-template-rows: repeat(2, 1fr);
	grid-column-gap: 4px;
	grid-row-gap: 4px;
	padding: 24px;
	margin: 0 auto;
}

.projects-empty-grid {
	display: grid;
	grid-template-columns: repeat(4, 1fr);
	grid-template-rows: repeat(1, 1fr);
	padding: 24px;
	margin: 0 auto;
}

.projects-empty-grid:first-child {
	grid-column: 1 / 4;
}

.project-success {
	border: 1px solid #41b883;
	width: 350px;
	border-radius: 8px;
	box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.05), 0 2px 4px rgba(0, 0, 0, 0.1);
	color: #ffffff;
	padding: 8px;
	text-align: center;
}

.project-fail {
	border: 1px solid #ff3860;
	width: 350px;
	border-radius: 8px;
	box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.05), 0 2px 4px rgba(0, 0, 0, 0.1);
	color: #ffffff;
	padding: 8px;
	text-align: center;
}

.project-running {
	border: 1px solid #ffdd57;
	width: 350px;
	border-radius: 8px;
	box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.05), 0 2px 4px rgba(0, 0, 0, 0.1);
	color: #ffffff;
	padding: 8px;
	text-align: center;
}

.project-claimed {
	border: 1px solid #9067c6;
	width: 350px;
	border-radius: 8px;
	box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.05), 0 2px 4px rgba(0, 0, 0, 0.1);
	color: #ffffff;
	padding: 8px;
	text-align: center;
}

.project-not-started {
	border: 1px solid #808080;
	width: 350px;
	border-radius: 8px;
	box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.05), 0 2px 4px rgba(0, 0, 0, 0.1);
	color: #ffffff;
	padding: 8px;
	text-align: center;
}

button {
	align-items: center;
	background-color: #41b883;
	border: 0;
	border-radius: 100px;
	box-sizing: border-box;
	color: #ffffff;
	cursor: pointer;
	display: inline-flex;
	font-family: -apple-system, system-ui, system-ui, "Segoe UI", Roboto, "Helvetica Neue", "Fira Sans", Ubuntu, Oxygen,
		"Oxygen Sans", Cantarell, "Droid Sans", "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol",
		"Lucida Grande", Helvetica, Arial, sans-serif;
	font-size: 16px;
	font-weight: 600;
	justify-content: center;
	line-height: 20px;
	max-width: 480px;
	min-height: 40px;
	min-width: 0px;
	overflow: hidden;
	padding: 0px;
	padding-left: 20px;
	padding-right: 20px;
	text-align: center;
	touch-action: manipulation;
	transition: background-color 0.167s cubic-bezier(0.4, 0, 0.2, 1) 0s,
		box-shadow 0.167s cubic-bezier(0.4, 0, 0.2, 1) 0s, color 0.167s cubic-bezier(0.4, 0, 0.2, 1) 0s;
	user-select: none;
	-webkit-user-select: none;
	vertical-align: middle;
}

button:hover,
button:focus {
	background-color: #35976b;
	color: #ffffff;
}

button:active {
	background: #34495e;
	color: rgb(255, 255, 255, 0.7);
}

button:disabled {
	cursor: not-allowed;
	background: rgba(65, 184, 131, 0.08);
	color: rgba(65, 184, 131, 0.3);
}
</style>
