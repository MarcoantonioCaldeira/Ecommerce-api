import { IsOptional, IsString, IsEnum, Min, Max, IsInt } from 'class-validator';

export class UpdateOrderDto{
  @IsOptional()
  @IsString()
  @IsEnum(['pending', 'processing', 'shipped', 'delivered', 'cancelled'])
  status?: string;
}