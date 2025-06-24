import { User } from '../../users/entities/user.entity';
import { Product } from '../../products/entities/products.entity';

export class Order {
  id: number;
  quantity: number;
  status: string;
  createdAt: Date;
  updatedAt: Date;
  user: User;
  product: Product;
}