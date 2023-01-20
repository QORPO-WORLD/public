### asset_locking
User can deposit a NFT into this contract where it will be locked for set period of time, 
during which the third party can see it is locked and allow the user certain actions. 
When the period expires, user can either lock it again, or withdraw the NFT.

### erc20_staking_12m
Contract to enable on-chain staking of ERC20 tokens for predefined period 
(in this case - 12 months)

### erc20_staking_12m_limited
Contract to enable on-chain staking of ERC20 tokens for predefined period, 
but only for a specific amount of users, after the "spots" are used, no new users
are allowed to stake
(in this case - 12 months)

### erc20_staking_fixed_fines
Contract to enable on-chain staking of ERC20 tokens with mechanisms to fine the user
if he wants to cancel the staking before the end of set period.

### erc20_vesting
Contract to enable continous withdrawals for investors at certain intervals

### VRFConsumer
Consumer contract to process result/-s from Verifiable Random Function

